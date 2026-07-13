-- ============================================================================
-- OCSP Stapling Plugin - PROOF OF CONCEPT (POC) - UNSUPPORTED
-- ============================================================================
-- Staples OCSP responses for certificates served dynamically by Kong.
--
-- How it works, per TLS handshake (certificate phase):
--   1. Resolve the client's SNI to a Kong certificate entity (exact match,
--      then leftmost-wildcard). No match means Kong is serving its static
--      default cert, which nginx staples natively - we step aside.
--   2. Serve the OCSP response from the shared dict when cached
--      (node-wide cache: one fetch covers every worker, unlike nginx's
--      native per-worker stapling cache).
--   3. On a cold cache, fetch from the responder inline so even the very
--      first handshake gets a staple. Fetch failures are negative-cached
--      for failure_ttl so a dead responder cannot add latency to every
--      handshake or be hammered with requests.
--   4. A cached response is refreshed in the background once 75% of
--      cache_ttl has elapsed, and kept (stale-if-error) until the
--      response's own nextUpdate time - so a flaky responder degrades to
--      a stale-but-valid staple, never an expired one and rarely none.
--   5. Certificate/SNI/ca_certificates changes (CRUD events) purge the
--      affected cache entries immediately; TTLs are only the fallback bound.
--
-- Requirement: the certificate entity's `cert` field must contain the full
-- chain (leaf + issuer), OR the configured trust anchors
-- (conf.ca_certificates / conf.trusted_certificate) must contain the
-- issuer. The issuer cert is needed to build the OCSP request.
--
-- It is NOT officially supported by Kong Inc.
-- Use at your own risk in production environments.
-- ============================================================================

local ffi = require "ffi"

-- ngx.ocsp only exists in the http subsystem; Kong also loads this handler
-- in the stream subsystem (stream_listen), where stapling doesn't apply.
local ssl, ocsp, http
if ngx.config.subsystem == "http" then
  ssl = require "ngx.ssl"
  ocsp = require "ngx.ocsp"
  http = require "resty.http"
end


local kong = kong
local ngx = ngx
local timer_at = ngx.timer.at
local C = ffi.C

local RESP_PREFIX = "ocsp_stapling:resp:"
local FRESH_PREFIX = "ocsp_stapling:fresh:"
local LOCK_PREFIX = "ocsp_stapling:lock:"
local FAIL_PREFIX = "ocsp_stapling:fail:"
local PEM_PREFIX = "ocsp_stapling:pem:"
local CA_PREFIX = "ocsp_stapling:ca:"
local SHM_KEY_PREFIX = "ocsp_stapling:"

-- fraction of the refresh interval after which a background refresh runs
local REFRESH_AT = 0.75
-- how long a refresh lock is held; bounds duplicate fetches if a refresh dies
local LOCK_TTL = 60
-- without a parseable nextUpdate, serve stale up to this multiple of cache_ttl
local STALE_FACTOR = 2
-- startup pre-warm: initial delay, and retry cadence while the datastore
-- is still empty (a hybrid DP may not have synced config yet)
local PREWARM_DELAY = 5
local PREWARM_RETRY_DELAY = 10
local PREWARM_MAX_ATTEMPTS = 12


-- libcrypto FFI for reading the response's nextUpdate. lua-resty-openssl
-- 1.5.x has no OCSP module, so declare the handful of functions we need.
-- Opaque pointers throughout; void* converts implicitly in LuaJIT FFI.
-- pcall-guarded: a duplicate cdef (or missing symbol later) simply
-- disables validity parsing and the STALE_FACTOR fallback applies.
pcall(ffi.cdef, [[
  void *d2i_OCSP_RESPONSE(void **a, const unsigned char **in, long len);
  void OCSP_RESPONSE_free(void *a);
  void *OCSP_response_get1_basic(void *resp);
  void OCSP_BASICRESP_free(void *a);
  void *OCSP_resp_get0(void *bs, int idx);
  int OCSP_single_get0_status(void *single, int *reason, void **revtime,
                              void **thisupd, void **nextupd);
]])
pcall(ffi.cdef, [[
  int ASN1_TIME_diff(int *pday, int *psec, const void *from, const void *to);
]])


local OCSPStaplingHandler = {
  PRIORITY = 1000,
  -- keep in sync with the kong-plugin-ocsp-stapling rockspec version
  VERSION = "0.5.1",
}


-- Seconds until the DER response's nextUpdate, or nil if it cannot be
-- determined (no nextUpdate field, parse error, missing symbols).
local function response_validity(resp_der)
  local ok, validity = pcall(function()
    local buf = ffi.new("const unsigned char*[1]",
                        ffi.cast("const unsigned char*", resp_der))
    local resp = C.d2i_OCSP_RESPONSE(nil, buf, #resp_der)
    if resp == nil then
      return nil
    end

    -- inner pcall so resp/basic are freed even if a symbol is missing or
    -- parsing throws part-way through
    local basic
    local parsed, secs = pcall(function()
      basic = C.OCSP_response_get1_basic(resp)
      if basic == nil then
        return nil
      end
      local single = C.OCSP_resp_get0(basic, 0)
      if single == nil then
        return nil
      end
      local nextupd = ffi.new("void*[1]")
      local thisupd = ffi.new("void*[1]")
      local revtime = ffi.new("void*[1]")
      local reason = ffi.new("int[1]")
      C.OCSP_single_get0_status(single, reason, revtime, thisupd, nextupd)
      if nextupd[0] == nil then
        return nil
      end
      local pday = ffi.new("int[1]")
      local psec = ffi.new("int[1]")
      -- from = NULL means "now"
      if C.ASN1_TIME_diff(pday, psec, nil, nextupd[0]) ~= 1 then
        return nil
      end
      return pday[0] * 86400 + psec[0]
    end)

    if basic ~= nil then
      C.OCSP_BASICRESP_free(basic)
    end
    C.OCSP_RESPONSE_free(resp)

    return parsed and secs or nil
  end)

  if not ok then
    return nil
  end
  return validity
end


-- warn about a missing/mistyped shared dict only once per worker, not per handshake
local warned_missing_shm = {}
-- dict names this worker has used, so CRUD-event purges know where to look
local seen_shm_names = {}

local function get_shm(conf)
  local shm = ngx.shared[conf.shm_name]
  if shm then
    seen_shm_names[conf.shm_name] = true
  elseif not warned_missing_shm[conf.shm_name] then
    warned_missing_shm[conf.shm_name] = true
    kong.log.err("shared dict '", conf.shm_name, "' is not defined in the ",
                 "nginx config (see nginx_http_lua_shared_dict); ",
                 "OCSP stapling is disabled")
  end
  return shm
end


-- SNI name -> certificate PEM from Kong's datastore (LMDB on hybrid DPs).
-- Returns nil (no error) when no dynamic cert covers this name.
local function db_lookup_cert_pem(sni_name)
  local sni, err = kong.db.snis:select_by_name(sni_name)
  if err then
    return nil, err
  end

  if not sni then
    -- e.g. proxy.example.com -> *.example.com
    local wildcard = sni_name:gsub("^[^.]+", "*", 1)
    if wildcard ~= sni_name then
      sni, err = kong.db.snis:select_by_name(wildcard)
      if err then
        return nil, err
      end
    end
  end

  if not sni then
    return nil
  end

  local certificate, err = kong.db.certificates:select(sni.certificate)
  if err then
    return nil, err
  end

  return certificate and certificate.cert or nil
end


local function get_cert_pem(sni_name, conf)
  -- `or 300` guards against plugin rows created before cert_cache_ttl existed
  return kong.cache:get(PEM_PREFIX .. sni_name,
                        { ttl = conf.cert_cache_ttl or 300 },
                        db_lookup_cert_pem, sni_name)
end


local function load_ca_pem(ca_id)
  local ca, err = kong.db.ca_certificates:select({ id = ca_id })
  if err then
    return nil, err
  end
  return ca and ca.cert or nil
end


-- Concatenated PEM of all configured trust anchors: referenced
-- ca_certificates entities plus the inline trusted_certificate, combined.
-- Returns nil (no error) when neither is configured. A dangling
-- ca_certificates ID is an error: better to fail the fetch (fail-open,
-- logged) than to silently validate against fewer anchors than configured.
local function get_trust_bundle(conf)
  -- unset optional fields can surface as ngx.null (a truthy userdata)
  -- instead of nil depending on how the config was stored - normalize
  local ids = conf.ca_certificates
  if ids == ngx.null then
    ids = nil
  end
  local inline = conf.trusted_certificate
  if inline == ngx.null then
    inline = nil
  end

  if (not ids or #ids == 0) and not inline then
    return nil
  end

  local parts = {}
  if ids then
    for _, id in ipairs(ids) do
      local pem, err = kong.cache:get(CA_PREFIX .. id,
                                      { ttl = conf.cert_cache_ttl or 300 },
                                      load_ca_pem, id)
      if err then
        return nil, "ca_certificates lookup for " .. id .. " failed: " .. tostring(err)
      end
      if not pem then
        return nil, "ca_certificate " .. id .. " not found"
      end
      parts[#parts + 1] = pem
    end
  end
  if inline then
    parts[#parts + 1] = inline
  end

  return table.concat(parts, "\n")
end


-- First PEM certificate block in a (possibly multi-cert) PEM string.
local function leaf_pem(cert_pem)
  return cert_pem:match("%-%-%-%-%-BEGIN CERTIFICATE%-%-%-%-%-.-%-%-%-%-%-END CERTIFICATE%-%-%-%-%-")
         or cert_pem
end


-- Does the responder URL match an allowlist entry? Entries are bare
-- hostnames ("ocsp.example.com") or scheme://host[:port] URLs. Comparison
-- is on PARSED components, never raw string prefixes - a prefix check
-- would let http://ocsp.example.com.evil.com through.
local function responder_allowed(responder_url, allowed)
  local parsed, err = http:parse_uri(responder_url, false)
  if not parsed then
    return false, "cannot parse responder URL: " .. tostring(err)
  end
  local scheme, host, port = parsed[1]:lower(), parsed[2]:lower(), parsed[3]

  for _, entry in ipairs(allowed) do
    if entry:find("://", 1, true) then
      local e = http:parse_uri(entry, false)
      if not e then
        -- a typo'd entry must not silently masquerade as a denial
        kong.log.warn("allowed_responders entry '", entry,
                      "' is not a parseable URL; ignoring it")
      elseif e[1]:lower() == scheme and e[2]:lower() == host and e[3] == port then
        return true
      end
    elseif entry:lower() == host then
      return true
    end
  end

  return false
end


-- Fetch a validated, DER-encoded OCSP response for the given PEM chain.
local function fetch_ocsp_response(cert_pem, conf)
  local der_chain, err = ssl.cert_pem_to_der(cert_pem)
  if not der_chain then
    return nil, "failed to convert PEM chain to DER: " .. tostring(err)
  end

  -- with trust anchors configured (ca_certificates entities and/or an
  -- inline trusted_certificate), responses are validated against leaf +
  -- those anchors (nginx ssl_stapling_verify semantics) rather than
  -- whatever chain came with the certificate entity
  local trust_pem, err = get_trust_bundle(conf)
  if err then
    return nil, err
  end

  local validate_der = der_chain
  if trust_pem then
    validate_der, err = ssl.cert_pem_to_der(leaf_pem(cert_pem) .. "\n" .. trust_pem)
    if not validate_der then
      return nil, "failed to convert trust anchors to DER: " .. tostring(err)
    end
  end

  local responder_url, err = ocsp.get_ocsp_responder_from_der_chain(der_chain)
  if not responder_url then
    return nil, "no OCSP responder in certificate (AIA): " .. tostring(err)
  end

  -- the AIA URL is attacker-influenced data (it comes from the uploaded
  -- certificate); with an allowlist configured, refuse anything else
  local allowed = conf.allowed_responders
  if allowed == ngx.null then
    allowed = nil
  end
  if allowed and #allowed > 0 then
    local ok, aerr = responder_allowed(responder_url, allowed)
    if not ok then
      return nil, "OCSP responder " .. responder_url ..
                  " is not in allowed_responders" ..
                  (aerr and (": " .. aerr) or "")
    end
  end

  local ocsp_req, err = ocsp.create_ocsp_request(der_chain)
  if not ocsp_req and trust_pem then
    -- entity chain lacks the issuer; retry with the trust anchors as
    -- the issuer source
    ocsp_req, err = ocsp.create_ocsp_request(validate_der)
  end
  if not ocsp_req then
    -- typically means the issuer cert is missing from the chain
    return nil, "failed to create OCSP request: " .. tostring(err)
  end

  local client = http.new()
  client:set_timeout(conf.http_timeout)

  local res, err = client:request_uri(responder_url, {
    method = "POST",
    body = ocsp_req,
    headers = {
      ["Content-Type"] = "application/ocsp-request",
    },
  })
  if not res then
    return nil, "OCSP responder request to " .. responder_url .. " failed: " .. tostring(err)
  end

  if res.status ~= 200 then
    return nil, "OCSP responder " .. responder_url .. " returned status " .. res.status
  end

  local ok, err = ocsp.validate_ocsp_response(res.body, validate_der)
  if not ok then
    return nil, "OCSP response validation failed: " .. tostring(err)
  end

  return res.body
end


-- Cache a fetched response. The response is kept until its own nextUpdate
-- (stale-if-error; never staple an expired response), while a background
-- refresh triggers at REFRESH_AT of the refresh interval. Without a
-- parseable nextUpdate, the stale window is STALE_FACTOR * cache_ttl.
local function cache_response(shm, sni_name, resp, conf)
  local validity = response_validity(resp)
  if validity and validity <= 0 then
    return nil, "responder returned an already-expired response"
  end

  local hard_ttl = validity or (conf.cache_ttl * STALE_FACTOR)
  local soft_ttl = math.min(conf.cache_ttl, hard_ttl) * REFRESH_AT

  local ok, err = shm:set(RESP_PREFIX .. sni_name, resp, hard_ttl)
  if not ok then
    kong.log.err("failed to cache OCSP response for ", sni_name, ": ", err)
  end
  shm:set(FRESH_PREFIX .. sni_name, true, soft_ttl)
  shm:delete(LOCK_PREFIX .. sni_name)
  shm:delete(FAIL_PREFIX .. sni_name)

  kong.log.debug("cached OCSP staple for ", sni_name, ": serve up to ",
                 hard_ttl, "s, refresh after ", soft_ttl, "s")
  return true
end


local function mark_failure(shm, sni_name, conf)
  -- `or 30` guards against plugin rows created before failure_ttl existed
  shm:set(FAIL_PREFIX .. sni_name, true, conf.failure_ttl or 30)
end


local function refresh(premature, sni_name, cert_pem, conf)
  if premature then
    return
  end

  local shm = get_shm(conf)
  if not shm then
    return
  end

  local resp, err = fetch_ocsp_response(cert_pem, conf)
  if resp then
    local ok
    ok, err = cache_response(shm, sni_name, resp, conf)
    if ok then
      return
    end
  end

  -- keep serving the cached (stale) response; back off before retrying
  kong.log.err("background OCSP refresh for ", sni_name, " failed ",
               "(serving cached response until it expires): ", err)
  mark_failure(shm, sni_name, conf)
  shm:delete(LOCK_PREFIX .. sni_name)
end


-- ---------------------------------------------------------------------------
-- Startup pre-warm
-- ---------------------------------------------------------------------------

-- The plugin's own config, read from the datastore (init_worker gets no
-- conf). O(1) indexed lookup via the unique plugins cache key - the same
-- way Kong's runloop resolves plugin configs; never a table scan on the
-- happy path. The scan fallback covers edge cases the key misses (e.g.
-- the plugin entity created in a non-default workspace) and is only run
-- when the caller asks for it.
-- Returns conf, found: `found` is true once the plugin entity has been
-- located (even if disabled), so the caller can stop retrying.
local function find_plugin_conf(include_scan)
  local key = kong.db.plugins:cache_key("ocsp-stapling")
  local plugin, err = kong.db.plugins:select_by_cache_key(key)
  if err then
    kong.log.warn("OCSP prewarm: plugin lookup failed: ", err)
  end
  if plugin then
    return plugin.enabled ~= false and plugin.config or nil, true
  end

  if not include_scan then
    return nil, false
  end

  for p, serr in kong.db.plugins:each(1000) do
    if serr then
      kong.log.warn("OCSP prewarm: cannot read plugins: ", serr)
      return nil, false
    end
    if p.name == "ocsp-stapling" then
      return p.enabled ~= false and p.config or nil, true
    end
  end
  return nil, false
end


-- Fetch staples for every non-wildcard SNI before any handshake needs them.
-- Runs on worker 0 only; retries cover a hybrid DP that hasn't synced its
-- config yet when the worker starts. The full-scan fallback runs at most
-- once, on the final attempt.
local function prewarm(premature, attempt)
  if premature then
    return
  end

  local conf, found = find_plugin_conf(attempt >= PREWARM_MAX_ATTEMPTS)

  if not conf then
    -- retry only while the entity hasn't been seen at all (config still
    -- syncing); a found-but-disabled plugin ends the search
    if not found and attempt < PREWARM_MAX_ATTEMPTS then
      timer_at(PREWARM_RETRY_DELAY, prewarm, attempt + 1)
    end
    return
  end

  if conf.prewarm == false then
    return
  end

  local shm = get_shm(conf)
  if not shm then
    return
  end

  local warmed, failed, skipped = 0, 0, 0
  for sni, err in kong.db.snis:each(1000) do
    if err then
      kong.log.warn("OCSP prewarm: cannot read snis: ", err)
      break
    end

    local name = sni.name
    if name:find("*", 1, true) then
      -- concrete hostnames behind a wildcard are unknown until a handshake
      skipped = skipped + 1

    elseif not shm:get(RESP_PREFIX .. name) then
      local resp, ferr
      local certificate, cerr = kong.db.certificates:select(sni.certificate)
      if certificate and certificate.cert then
        resp, ferr = fetch_ocsp_response(certificate.cert, conf)
        if resp then
          local ok
          ok, ferr = cache_response(shm, name, resp, conf)
          if not ok then
            resp = nil
          end
        end
      else
        ferr = cerr or "certificate not found"
      end

      if resp then
        warmed = warmed + 1
      else
        failed = failed + 1
        mark_failure(shm, name, conf)
        kong.log.warn("OCSP prewarm for ", name, " failed: ", ferr)
      end
    end
  end

  if warmed + failed + skipped > 0 then
    kong.log.notice("OCSP prewarm done: ", warmed, " stapled, ", failed,
                    " failed, ", skipped, " wildcard SNIs skipped")
  end
end


-- ---------------------------------------------------------------------------
-- CRUD-event cache invalidation
-- ---------------------------------------------------------------------------

local function purge_sni(sni_name)
  kong.cache:invalidate_local(PEM_PREFIX .. sni_name)
  for name in pairs(seen_shm_names) do
    local shm = ngx.shared[name]
    if shm then
      shm:delete(RESP_PREFIX .. sni_name)
      shm:delete(FRESH_PREFIX .. sni_name)
      shm:delete(FAIL_PREFIX .. sni_name)
      shm:delete(LOCK_PREFIX .. sni_name)
    end
  end
  kong.log.debug("purged OCSP cache for ", sni_name)
end


local function purge_all()
  for name in pairs(seen_shm_names) do
    local shm = ngx.shared[name]
    if shm then
      for _, key in ipairs(shm:get_keys(0)) do
        if key:sub(1, #SHM_KEY_PREFIX) == SHM_KEY_PREFIX then
          if key:sub(1, #RESP_PREFIX) == RESP_PREFIX then
            kong.cache:invalidate_local(
              PEM_PREFIX .. key:sub(#RESP_PREFIX + 1))
          end
          shm:delete(key)
        end
      end
    end
  end
  kong.log.debug("purged all OCSP cache entries")
end


function OCSPStaplingHandler:init_worker()
  if ngx.config.subsystem ~= "http" then
    return
  end

  local worker_events = kong.worker_events
  if not worker_events then
    return
  end

  -- an SNI changed: purge that name (wildcard SNIs cover many cached
  -- concrete names, so purge everything for those)
  worker_events.register(function(data)
    local name = data.entity and data.entity.name
    if name and not name:find("*", 1, true) then
      purge_sni(name)
    else
      purge_all()
    end
  end, "crud", "snis")

  -- a certificate changed: affected SNIs aren't in the event, purge all
  worker_events.register(purge_all, "crud", "certificates")

  -- a CA trust anchor changed: cached responses were validated against
  -- the old anchors, drop them along with the cached CA PEM
  worker_events.register(function(data)
    local id = data.entity and data.entity.id
    if id then
      kong.cache:invalidate_local(CA_PREFIX .. id)
    end
    purge_all()
  end, "crud", "ca_certificates")

  -- DB-less/hybrid full sync replaces config wholesale with no CRUD events
  worker_events.register(purge_all, "declarative", "reconfigure")

  -- pre-warm staples so even the first handshake after startup hits cache;
  -- one worker only, and pointless on a control plane (no proxy TLS)
  if ngx.worker.id() == 0
     and kong.configuration.role ~= "control_plane" then
    timer_at(PREWARM_DELAY, prewarm, 1)
  end
end


function OCSPStaplingHandler:certificate(conf)
  if not ocsp then
    return -- stream subsystem: no OCSP stapling support
  end

  local sni_name = ssl.server_name()
  if not sni_name then
    return
  end

  local shm = get_shm(conf)
  if not shm then
    return
  end

  local resp = shm:get(RESP_PREFIX .. sni_name)

  if not resp then
    if shm:get(FAIL_PREFIX .. sni_name) then
      return -- recent fetch failure; back off instead of hammering the responder
    end

    local cert_pem, err = get_cert_pem(sni_name, conf)
    if err then
      kong.log.err("certificate lookup for ", sni_name, " failed: ", err)
      return
    end
    if not cert_pem then
      -- no dynamic cert for this SNI; nginx staples the static cert itself
      return
    end

    -- cold cache: fetch inline so the first handshake is stapled too
    resp, err = fetch_ocsp_response(cert_pem, conf)
    if resp then
      local ok
      ok, err = cache_response(shm, sni_name, resp, conf)
      if not ok then
        resp = nil
      end
    end
    if not resp then
      kong.log.err("OCSP fetch for ", sni_name, " failed: ", err)
      mark_failure(shm, sni_name, conf)
      return
    end

  elseif not shm:get(FRESH_PREFIX .. sni_name)
     and not shm:get(FAIL_PREFIX .. sni_name) then
    -- cached but ageing: serve it, refresh in the background (one worker only)
    if shm:add(LOCK_PREFIX .. sni_name, true, LOCK_TTL) then
      local cert_pem = get_cert_pem(sni_name, conf)
      if cert_pem then
        local ok, err = timer_at(0, refresh, sni_name, cert_pem, conf)
        if not ok then
          kong.log.err("failed to schedule OCSP refresh for ", sni_name, ": ", err)
          shm:delete(LOCK_PREFIX .. sni_name)
        end
      end
    end
  end

  local ok, err = ocsp.set_ocsp_status_resp(resp)
  if not ok then
    kong.log.err("failed to set OCSP staple for ", sni_name, ": ", err)
  elseif err == "no status req" then
    -- client did not include the status_request extension; nothing sent
    kong.log.debug("client did not request OCSP stapling for ", sni_name)
  else
    kong.log.debug("stapled OCSP response for ", sni_name)
  end
end


return OCSPStaplingHandler
