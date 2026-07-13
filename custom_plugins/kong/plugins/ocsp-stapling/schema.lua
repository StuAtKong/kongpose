-- ============================================================================
-- OCSP Stapling Plugin - PROOF OF CONCEPT (POC) - UNSUPPORTED
-- ============================================================================
-- Staples OCSP responses for certificates served dynamically by Kong
-- (certificate + SNI entities added via the Admin API). Kong's static
-- certs (kong.conf ssl_cert) are already stapled natively by nginx;
-- this plugin covers the ssl_certificate_by_lua path that nginx cannot.
--
-- Must be enabled GLOBALLY: the certificate phase only runs global plugins
-- (no route/service is known during the TLS handshake).
--
-- It is NOT officially supported by Kong Inc.
-- Use at your own risk in production environments.
-- ============================================================================

local typedefs = require "kong.db.schema.typedefs"


local PLUGIN_NAME = "ocsp-stapling"


local schema = {
  name = PLUGIN_NAME,
  fields = {
    { consumer = typedefs.no_consumer },
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    { protocols = typedefs.protocols { default = { "https" } } },
    { config = {
        type = "record",
        fields = {
          { cache_ttl = {
              type = "number",
              default = 3600,
              gt = 0,
              description = "Refresh interval in seconds: a background refresh of the cached OCSP response triggers at 75% of this. The response itself is served until its own nextUpdate time (stale-if-error), or up to 2x this value if nextUpdate cannot be parsed."
          }},
          { http_timeout = {
              type = "number",
              default = 5000,
              gt = 0,
              description = "Timeout in milliseconds for the HTTP request to the OCSP responder"
          }},
          { prewarm = {
              type = "boolean",
              default = true,
              description = "Fetch OCSP responses for all (non-wildcard) SNIs at startup, so the first handshake after a restart is stapled from cache instead of fetching inline."
          }},
          { failure_ttl = {
              type = "number",
              default = 30,
              gt = 0,
              description = "How long (seconds) a fetch failure is negative-cached. While set, handshakes for that SNI proceed unstapled immediately instead of re-contacting the failing responder."
          }},
          { cert_cache_ttl = {
              type = "number",
              default = 300,
              gt = 0,
              description = "How long (seconds) the SNI-to-certificate DB lookup is cached. Bounds how quickly a rotated certificate picks up a fresh OCSP response."
          }},
          { shm_name = {
              type = "string",
              default = "kong",
              description = "Name of the lua_shared_dict used to cache OCSP responses. Must exist in the nginx config; add a dedicated one via nginx_http_lua_shared_dict (e.g. 'ocsp_stapling 5m') or leave the default to use Kong's general-purpose 'kong' dict."
          }},
          { allowed_responders = {
              type = "array",
              required = false,
              -- an empty array is rejected: it would read as "locked down"
              -- while behaving as allow-all; allow-all must be the explicit
              -- absence of this field
              len_min = 1,
              elements = { type = "string", len_min = 1 },
              description = "Allowlist of OCSP responders the plugin may contact (at least one entry when set). Entries are bare hostnames ('ocsp.example.com') or scheme://host[:port] URLs; the responder URL from the certificate's AIA extension must match one or the fetch is refused (fail-open, logged). Unset allows any responder - set this wherever certificate management is delegated, to close the SSRF vector."
          }},
          { ca_certificates = {
              type = "array",
              required = false,
              elements = typedefs.uuid,
              description = "IDs of Kong ca_certificates entities to use as trust anchors when validating OCSP responses (the preferred mechanism; same referencing convention as mtls-auth). Combined with trusted_certificate if both are set."
          }},
          { trusted_certificate = {
              type = "string",
              required = false,
              description = "Optional inline PEM bundle used as a trust anchor when validating OCSP responses, instead of the chain stored in the certificate entity. Analogous to nginx's ssl_trusted_certificate with ssl_stapling_verify. Prefer ca_certificates; this remains for anchors that aren't CA certs (e.g. a delegated responder cert) and quick tests. Either also serves as an issuer-certificate fallback when a certificate entity contains only the leaf."
          }},
        },
      },
    },
  },
}

return schema
