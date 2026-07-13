-- Happy-path tests against a mock OCSP responder.
--
-- Fixtures (pre-generated, valid ~100 years; OCSP response nextUpdate 2036):
--   * a test CA
--   * a leaf for SNI "stapled.test" whose authorityInfoAccess points at
--     http://127.0.0.1:10500/ - served by the http_mock fixture below
--   * a canned, CA-signed OCSP response (status: good) for that leaf,
--     embedded base64. The plugin's request carries no nonce, so a canned
--     response is valid regardless of the request bytes.
--
-- Verifying the staple needs a TLS client that reports the status_request
-- extension; lua-resty clients don't expose it, so these tests shell out
-- to the openssl CLI (present in the Pongo image) and are skipped if it
-- is missing.

local helpers = require "spec.helpers"

local PLUGIN_NAME = "ocsp-stapling"

local LEAF_CERT = [[
-----BEGIN CERTIFICATE-----
MIIDYTCCAkmgAwIBAgIUE621OfZOupuZsfanGZtlL3HzkAMwDQYJKoZIhvcNAQEL
BQAwHTEbMBkGA1UEAwwSUG9uZ28gT0NTUCBUZXN0IENBMCAXDTI2MDcxMzEyMTU1
NVoYDzIxMjYwNjE5MTIxNTU1WjAXMRUwEwYDVQQDDAxzdGFwbGVkLnRlc3QwggEi
MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDGz+g47H0CTOAx021otEQKXsZN
RNzmVaeKydAsPxdCALKUUiXn+wMjdvGpzoUdSFTvcllHrU91cn/ywEpCVFBO1fzH
s6oDUjqtq7yvb/CFel8bhtcq/zuQLWDjf0XOzJ/GGXYijFH6DwSUVlZp2WsgU5tx
J908KHJy0rSKDDhYPiHGvlLKJRlQszz1XmZuymDbcsWunSTNPx/FCyBXau5wEeyJ
HfZW5uIK4i+vT1RrDXBrtItGsBAowDyZBxd4IGJVokDtJfB8wSvNu96EDWmTWnTR
ae/RpMxM+aAhE2hmnEl+zg9Fl+iBMW0p/3Ywhcwf/7F+U3AgiPcIQ8fa3dq1AgMB
AAGjgZwwgZkwFwYDVR0RBBAwDoIMc3RhcGxlZC50ZXN0MDMGCCsGAQUFBwEBBCcw
JTAjBggrBgEFBQcwAYYXaHR0cDovLzEyNy4wLjAuMToxMDUwMC8wCQYDVR0TBAIw
ADAdBgNVHQ4EFgQUCm1y9HJrDaktwEoNk9SoEccrVW8wHwYDVR0jBBgwFoAUzYWZ
B/MWw9BeZxuMBhCuMvgS6tIwDQYJKoZIhvcNAQELBQADggEBAM4Jwb3Kw/Vh79jt
3IrkgcC7l/odV+IQJy0e7eCqdUG2i53S3wah60mjy0j4aow5uBwWVPNIkF3srRsJ
7Ty/PoQ0EWq1MTWOFR/GPk8ymL3dbo6TkaaF0TcXPFuTXA2AaVGzXNsWpYUaoOOV
Kgk4SGuF3LLUvRQOyztJpRSs8mrQUZEYUTgMDNx1mmNkYBZ2dYOEOl2LIG93SZj2
Z0jYAT+G7oXWg0RFUqWg+OWriccovkNj0rmle9mfQPI3DihrYNnWZVymcHRpCP+q
JZwlSNZXStb2eILSmO5Ob72skLw0zaJCOvkbGtrCsDI35/3y2a3CwY4wTUwtvzPg
FAlTLHM=
-----END CERTIFICATE-----
]]

local LEAF_KEY = [[
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDGz+g47H0CTOAx
021otEQKXsZNRNzmVaeKydAsPxdCALKUUiXn+wMjdvGpzoUdSFTvcllHrU91cn/y
wEpCVFBO1fzHs6oDUjqtq7yvb/CFel8bhtcq/zuQLWDjf0XOzJ/GGXYijFH6DwSU
VlZp2WsgU5txJ908KHJy0rSKDDhYPiHGvlLKJRlQszz1XmZuymDbcsWunSTNPx/F
CyBXau5wEeyJHfZW5uIK4i+vT1RrDXBrtItGsBAowDyZBxd4IGJVokDtJfB8wSvN
u96EDWmTWnTRae/RpMxM+aAhE2hmnEl+zg9Fl+iBMW0p/3Ywhcwf/7F+U3AgiPcI
Q8fa3dq1AgMBAAECggEAGY7WsqKsO2R4mc8tTH2IFbEzWvGUWEQAotXo3hdKPSDr
1CdvWhApyiBbVtIGyMnoqVOQ6Kb+BQIwMpvHsBk4rbnSojWVkJG8m2Dtg7wnNnGR
0m8WMB/Zn2JGB1jwN3KUw5m4Vx6k1zmhBBTJTRg3LlOxMu3GAhrNA7fUn76Ma8Nu
nDOxA4Q7qecBO7KJpAMUoe8JtqyoiobG3vAbr/vB6Qfhr/OrDvn/exXUjSiYrMFJ
r66qFoQocpddbxMGmVsS60on/DLjvxGFSfM+1qT6U+lZVntIc9dCcEK/nGSBta28
e7WWHovonZ6ZV9WliJLn1uqMAgyiSFV4LD9V367dTQKBgQDIzOgFRx0jLLv08cfH
6rE3dhRYYQZ4L9od9TEQfobxjgq3daDGBMlV7PtW95aq5uziZs4AjoSsjxsd3oUl
f+1NYQ6R7BucsYxOY29HpGLVq5qmqFpcss7XFCemz4H/k/mO2jpMgMVspYtppvmW
zw7BBDPTdR/5x55ChPXU0VTFywKBgQD9dxP6tE8uIyfVaHIV0vz5eimoWfG73OQh
BtnE+VQ8bQyf4xqlvfuvBwrNzzxEmCcLPWCEbI/vxvx6cyXbG5vfvSamsq3lQG04
OVTcVsDxSLhSpb7AJfw0f+rNjxCxOfbNMe37OLZuznRdUaV6T51/y5i6+6jsbWeD
sQzMcl/RfwKBgGeJQBl4kY2Rg1jJUjnCyZ3PRK5NWQifo9fOlX3rv6jNlLkD7eIs
laO4jeBJyWZVq88RMycWVVKkd1bvZbfwPmunn9ud4p7o7W991eMa39tMoHFOXUlu
6Tf9LHTWijE+G2+NFoJb43Ah68COWCNqoDDl+dMOkW45f2DNLfSN+ygBAoGBAKMK
7zostGZcTOpVNlXdk8czEwrtWLdcvw6Tpo+zRsFb8GwFHYYSMI0FPajoLr99FFiB
kc19PBWkbZKi8W4BU4JX3T4L4BqBGAC7uF/IGnLbMV5QqeRWSubGhhbWeYlXXO/f
t1MLxyZ9/ZJty8Fi51BmegeFjMMRGS44PKBizkonAoGALlbzSiI6qtTm5LCe6q6N
I5Bt0cwtPQ9gV9F+0ecGn+GKcfBgzN7Nm1z/i+OyNq+sD63bWWMyyA796CukgXW4
FsyUXYE56YOunbbcxPrx2MKf4mgg33qZY+5X8uIvKR8fCDkW0uMGJmWkmkx2QZTV
2rt58Px023w+jLKwG3PZ0RQ=
-----END PRIVATE KEY-----
]]

local CA_CERT = [[
-----BEGIN CERTIFICATE-----
MIIDHTCCAgWgAwIBAgIUA3Fng1ltmr3bItvdkl1kPEhbq3AwDQYJKoZIhvcNAQEL
BQAwHTEbMBkGA1UEAwwSUG9uZ28gT0NTUCBUZXN0IENBMCAXDTI2MDcxMzEyMTU1
NVoYDzIxMjYwNjE5MTIxNTU1WjAdMRswGQYDVQQDDBJQb25nbyBPQ1NQIFRlc3Qg
Q0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDdeTImFvk3L7FCqC0g
eYBy7tsySPZgDgKTPuHM4V0O34eXrp3a4mLZyoBltxaP44JmN/RfZfhfPQwscRL5
m6sGMsZx2uQSHxosqr2VkH2OoEbhO2YpegIt8OpoJJzWiFzir954jMB2ZZEYC5n4
ukHZidruBcIDaJ33K5hprfHyhQsdfaqLt3EwP5C0CXUcGs0feOkqHsxV/woVa+sb
x2589qa++un5eparla0FdV7j+TBEvddyy1WrWTiL3wmU9POxGE7C6WEDq5aEL1N6
kCc3AKiDlNdJPCJaMU8T02ggJqbYO1x5sSjQtRZhLSIgE0H2OwkA/sq4qaf14wE4
66CfAgMBAAGjUzBRMB0GA1UdDgQWBBTNhZkH8xbD0F5nG4wGEK4y+BLq0jAfBgNV
HSMEGDAWgBTNhZkH8xbD0F5nG4wGEK4y+BLq0jAPBgNVHRMBAf8EBTADAQH/MA0G
CSqGSIb3DQEBCwUAA4IBAQB+4XqETx8YKk7wh7dThPf0huSH4nbafJCScI9g7usG
ieGPDO3xhWekRT69FwwGsFQro/5moAa12R6RLOM0qOPUVSdYxuTqVWFFVshBcsic
NC+RSomCPWw2Vx/Xm0AGvEpN/HnSH8BuPLbz10dP9yzS61HAf8mmkf8R/QinQT7m
FfO3NGP0BAVvcze+KFZb+WsGpt/um5/ySzSB/h6N5fWOHjK3dE3CqtDr1vTOz0Zq
+FUBBbbRUaZ4XJR37/57uV6d25sx5Dzjl3kTC+rR0zQ+hMBBh/K0BzGNgK8dgQQ8
1199Umie5KTMT5rkUgSYYjs7EYXvchrjq2sfeotezI1I
-----END CERTIFICATE-----
]]

-- an unrelated self-signed CA (same fixture as 02-integration_spec) used
-- as a deliberately WRONG trust anchor in the strict-validation tests
local WRONG_CA_CERT = [[
-----BEGIN CERTIFICATE-----
MIIDNDCCAhygAwIBAgIUSmAJelehDLpl1gsLsp4sqOGx3cYwDQYJKoZIhvcNAQEL
BQAwFjEUMBIGA1UEAwwLbm8tYWlhLnRlc3QwIBcNMjYwNzEzMTIxNjA3WhgPMjEy
NjA2MTkxMjE2MDdaMBYxFDASBgNVBAMMC25vLWFpYS50ZXN0MIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0OAaexSAQoqgYmjA1k1/bFbOAMJRt/ou8OvB
OO7mjma3Hf2vpM17t1MskYPbOnhfKubJid++9Jc/9k491elu2WfcieQI4K37Raa5
34PdiIPA7uk0KNe4XeFlh9UplBYevjJCHPX9KmHTSizd075Nb6+EdiVlrAmyjsRk
b4yyrkR2uw0gcEWKAqothYEbU2AJrqjhKJ2nrUUXx6QD1hD0/lZJlbkI11HY7Fo6
JUj4t1rWS0hSg0F4dF5NtfvbxnwCdXtRCqFhGNKLI4ypkK1vEIngQ29PQdrJN0y5
gCo0iUF95AnUsuRHcdPOS+1+EBoisNnzFuhl8p96hRq/8oImHwIDAQABo3gwdjAd
BgNVHQ4EFgQUtbv2fi6yZ4T29xWo7zYyxYgty1gwHwYDVR0jBBgwFoAUtbv2fi6y
Z4T29xWo7zYyxYgty1gwDwYDVR0TAQH/BAUwAwEB/zAjBgNVHREEHDAaggtuby1h
aWEudGVzdIILKi53aWxkLnRlc3QwDQYJKoZIhvcNAQELBQADggEBAHnRtPeue6hx
bYrHBZfLtnJ9ittfS/UYgIhSOKHr8fBcwvRH54Sb6gNal/A8FRX11RwLxSbPji2W
ex2aVLC9H1mpl7dOwSDlEKK23G+4Bh0n29zTzm20v92QAsLTNt5JE3k5T0jt5auv
MTsvMlCX0GvvY6T3gehaU5W1WtWzd8pm7ZWb+d3NyUK1s9pXFyRe3dUyOzudAZqh
Tum4/kd5q0zBA/iiprpVOoviCK8idsx8zXBPprCF7ogltdQuBVYepL7i+qbkdjRg
vnFFJ1GPuoGk8Le495BTmVN4zbZ9KXXLqGxDbDxWKiidvMjj9soYXMXpzvrfFAmp
bNNKpScedwA=
-----END CERTIFICATE-----
]]

-- DER OCSP response, base64: status good for LEAF_CERT, signed by the CA,
-- nextUpdate 2036-07-10
local OCSP_RESPONSE_B64 =
  "MIIFCQoBAKCCBQIwggT+BgkrBgEFBQcwAQEEggTvMIIE6zCBq6EfMB0xGzAZBgNVBAMMElBvbmdvIE9DU1AgVGVzdCBDQRgPMjAyNjA3MTMxMjE1NTVaMHcwdTBNMAkGBSsOAwIaBQAEFCMSLaFDCrxapVn/2X9M69X7fufLBBTNhZkH8xbD0F5nG4wGEK4y+BLq0gIUE621OfZOupuZsfanGZtlL3HzkAOAABgPMjAyNjA3MTMxMjE1NTVaoBEYDzIwMzYwNzEwMTIxNTU1WjANBgkqhkiG9w0BAQsFAAOCAQEAweMeQ7+ogmEwhTaqywzG8utcpfGFu7NB/2MEBKBgCaq9j6ffZSjmoLYfht3BGLZHhV1AYz2oe7Z5oiR5Ly3ZpO5ODXCndAQkw95HqqAN5pSgQML1YXw2QEaRW2Lh/i1W/u1C3SVO6enHHOmsh6YPCO5anOHDhDP4qxr238tk1KRJdT3jFbse/vNgbD+POkEzaeh8wbVUTQ8b466rE5N3x8Oob62ZkPBsYn11XendKMAPE/dp/iLYgO+MEBVJnneScU2SP3ZNvmklh+PozU8rnZHqgQQ2vHVUyAk9h5eaNcyxhmE5yX2wYZhqQHvkGezCuGfrKnVeaP7V9lPDBHczjqCCAyUwggMhMIIDHTCCAgWgAwIBAgIUA3Fng1ltmr3bItvdkl1kPEhbq3AwDQYJKoZIhvcNAQELBQAwHTEbMBkGA1UEAwwSUG9uZ28gT0NTUCBUZXN0IENBMCAXDTI2MDcxMzEyMTU1NVoYDzIxMjYwNjE5MTIxNTU1WjAdMRswGQYDVQQDDBJQb25nbyBPQ1NQIFRlc3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDdeTImFvk3L7FCqC0geYBy7tsySPZgDgKTPuHM4V0O34eXrp3a4mLZyoBltxaP44JmN/RfZfhfPQwscRL5m6sGMsZx2uQSHxosqr2VkH2OoEbhO2YpegIt8OpoJJzWiFzir954jMB2ZZEYC5n4ukHZidruBcIDaJ33K5hprfHyhQsdfaqLt3EwP5C0CXUcGs0feOkqHsxV/woVa+sbx2589qa++un5eparla0FdV7j+TBEvddyy1WrWTiL3wmU9POxGE7C6WEDq5aEL1N6kCc3AKiDlNdJPCJaMU8T02ggJqbYO1x5sSjQtRZhLSIgE0H2OwkA/sq4qaf14wE466CfAgMBAAGjUzBRMB0GA1UdDgQWBBTNhZkH8xbD0F5nG4wGEK4y+BLq0jAfBgNVHSMEGDAWgBTNhZkH8xbD0F5nG4wGEK4y+BLq0jAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQB+4XqETx8YKk7wh7dThPf0huSH4nbafJCScI9g7usGieGPDO3xhWekRT69FwwGsFQro/5moAa12R6RLOM0qOPUVSdYxuTqVWFFVshBcsicNC+RSomCPWw2Vx/Xm0AGvEpN/HnSH8BuPLbz10dP9yzS61HAf8mmkf8R/QinQT7mFfO3NGP0BAVvcze+KFZb+WsGpt/um5/ySzSB/h6N5fWOHjK3dE3CqtDr1vTOz0Zq+FUBBbbRUaZ4XJR37/57uV6d25sx5Dzjl3kTC+rR0zQ+hMBBh/K0BzGNgK8dgQQ81199Umie5KTMT5rkUgSYYjs7EYXvchrjq2sfeotezI1I"

-- nginx server block serving the canned response on the port the leaf's
-- AIA extension points at
local fixtures = {
  http_mock = {
    ocsp_responder = [[
      server {
        listen 127.0.0.1:10500;
        location / {
          content_by_lua_block {
            ngx.header["Content-Type"] = "application/ocsp-response"
            ngx.print(ngx.decode_base64("]] .. OCSP_RESPONSE_B64 .. [["))
          }
        }
      }
    ]],
  },
}


local openssl_available = os.execute("openssl version > /dev/null 2>&1")
-- Lua 5.1 os.execute returns a number; 5.2+/LuaJIT COMPAT52 a boolean
openssl_available = openssl_available == true or openssl_available == 0

local function s_client_status(sni)
  local cmd = ("echo | openssl s_client -connect %s:%d -servername %s -status 2>/dev/null")
              :format(helpers.get_proxy_ip(true), helpers.get_proxy_port(true), sni)
  local pipe = assert(io.popen(cmd))
  local output = pipe:read("*a")
  pipe:close()
  return output
end

local function count_log_lines(needle)
  local f = io.open(helpers.test_conf.prefix .. "/logs/error.log", "r")
  if not f then
    return 0
  end
  local n = 0
  for line in f:lines() do
    if line:find(needle, 1, true) then
      n = n + 1
    end
  end
  f:close()
  return n
end


for _, strategy in helpers.each_strategy() do

  describe(PLUGIN_NAME .. ": (responder, happy path) [#" .. strategy .. "]", function()

    lazy_setup(function()
      local bp = helpers.get_db_utils(strategy,
                                      { "certificates", "snis", "plugins" },
                                      { PLUGIN_NAME })

      local cert = bp.certificates:insert({
        cert = LEAF_CERT .. CA_CERT, -- full chain: issuer needed for the OCSP request
        key = LEAF_KEY,
      })

      bp.snis:insert({ name = "stapled.test", certificate = { id = cert.id } })

      bp.plugins:insert({
        name = PLUGIN_NAME,
        config = {}, -- defaults: prewarm on, entity-chain validation
      })

      assert(helpers.start_kong({
        database = strategy,
        plugins = "bundled," .. PLUGIN_NAME,
        log_level = "debug",
        nginx_conf = "spec/fixtures/custom_nginx.template",
      }, nil, nil, fixtures))
    end)

    lazy_teardown(function()
      helpers.stop_kong()
    end)


    it("pre-warms the staple at startup, before any handshake", function()
      assert.logfile().has.line("OCSP prewarm done: 1 stapled, 0 failed", true, 30)
      assert.logfile().has.line("cached OCSP staple for stapled.test", true, 5)
    end)

    it("staples a validated OCSP response on the first handshake", function()
      if not openssl_available then
        return pending("openssl CLI not available")
      end

      local output = s_client_status("stapled.test")
      assert.matches("OCSP Response Status: successful", output, nil, true)
      assert.matches("Cert Status: good", output, nil, true)
    end)

    it("serves subsequent handshakes from cache without refetching", function()
      if not openssl_available then
        return pending("openssl CLI not available")
      end

      local before = count_log_lines("cached OCSP staple for stapled.test")

      for _ = 1, 3 do
        local output = s_client_status("stapled.test")
        assert.matches("Cert Status: good", output, nil, true)
      end

      -- still only the prewarm-time fetch; handshakes hit the cache
      assert.equal(before, count_log_lines("cached OCSP staple for stapled.test"))
    end)

  end)


  describe(PLUGIN_NAME .. ": (responder, background refresh) [#" .. strategy .. "]", function()

    lazy_setup(function()
      local bp = helpers.get_db_utils(strategy,
                                      { "certificates", "snis", "plugins" },
                                      { PLUGIN_NAME })

      local cert = bp.certificates:insert({
        cert = LEAF_CERT .. CA_CERT,
        key = LEAF_KEY,
      })

      bp.snis:insert({ name = "stapled.test", certificate = { id = cert.id } })

      -- cache_ttl=1 -> the fresh window is 0.75s, so handshakes shortly
      -- after the pre-warm trigger the background refresh path
      bp.plugins:insert({
        name = PLUGIN_NAME,
        config = { cache_ttl = 1 },
      })

      assert(helpers.start_kong({
        database = strategy,
        plugins = "bundled," .. PLUGIN_NAME,
        log_level = "debug",
        nginx_conf = "spec/fixtures/custom_nginx.template",
      }, nil, nil, fixtures))
    end)

    lazy_teardown(function()
      helpers.stop_kong()
    end)


    it("refreshes the cached response in the background once the fresh window elapses", function()
      if not openssl_available then
        return pending("openssl CLI not available")
      end

      -- first fill: the startup pre-warm
      assert.logfile().has.line("cached OCSP staple for stapled.test", true, 30)

      -- handshakes after the 0.75s fresh window serve the cached staple
      -- and schedule a refresh; a second "cached" line proves it ran
      helpers.wait_until(function()
        local output = s_client_status("stapled.test")
        assert.matches("Cert Status: good", output, nil, true)
        return count_log_lines("cached OCSP staple for stapled.test") >= 2
      end, 15)
    end)

  end)


  describe(PLUGIN_NAME .. ": (responder, allowed_responders) [#" .. strategy .. "]", function()

    local plugin_id

    lazy_setup(function()
      local bp = helpers.get_db_utils(strategy,
                                      { "certificates", "snis", "plugins" },
                                      { PLUGIN_NAME })

      local cert = bp.certificates:insert({
        cert = LEAF_CERT .. CA_CERT,
        key = LEAF_KEY,
      })

      bp.snis:insert({ name = "stapled.test", certificate = { id = cert.id } })

      -- allowlist that does NOT cover the mock responder (127.0.0.1);
      -- failure_ttl=1 so the negative cache clears quickly after the
      -- allowlist is fixed mid-test
      local plugin = bp.plugins:insert({
        name = PLUGIN_NAME,
        config = {
          prewarm = false,
          failure_ttl = 1,
          allowed_responders = { "http://ocsp.allowed.example.com" },
        },
      })
      plugin_id = plugin.id

      assert(helpers.start_kong({
        database = strategy,
        plugins = "bundled," .. PLUGIN_NAME,
        nginx_conf = "spec/fixtures/custom_nginx.template",
      }, nil, nil, fixtures))
    end)

    lazy_teardown(function()
      helpers.stop_kong()
    end)


    it("refuses a responder that is not on the allowlist", function()
      if not openssl_available then
        return pending("openssl CLI not available")
      end

      local output = s_client_status("stapled.test")
      assert.matches("no response sent", output, nil, true)
      assert.logfile().has.line("is not in allowed_responders", true, 5)
    end)

    it("staples once the allowlist covers the responder host", function()
      if not openssl_available then
        return pending("openssl CLI not available")
      end

      local admin = helpers.admin_client()
      local res = admin:patch("/plugins/" .. plugin_id, {
        headers = { ["Content-Type"] = "application/json" },
        body = { config = { allowed_responders = { "127.0.0.1" } } },
      })
      assert.res_status(200, res)
      admin:close()

      -- wait out config propagation and the 1s failure marker
      helpers.wait_until(function()
        local output = s_client_status("stapled.test")
        return output:find("Cert Status: good", 1, true) ~= nil
      end, 15)
    end)

  end)


  describe(PLUGIN_NAME .. ": (responder, strict validation) [#" .. strategy .. "]", function()

    lazy_setup(function()
      local bp = helpers.get_db_utils(strategy,
                                      { "certificates", "snis", "plugins", "ca_certificates" },
                                      { PLUGIN_NAME })

      local cert = bp.certificates:insert({
        cert = LEAF_CERT .. CA_CERT,
        key = LEAF_KEY,
      })

      bp.snis:insert({ name = "stapled.test", certificate = { id = cert.id } })

      -- trust anchor is an UNRELATED CA: the mock's response is signed by
      -- the test CA, so validation must reject it and no staple is sent
      local wrong_ca = bp.ca_certificates:insert({
        cert = WRONG_CA_CERT,
      })

      bp.plugins:insert({
        name = PLUGIN_NAME,
        config = {
          prewarm = false,
          ca_certificates = { wrong_ca.id },
        },
      })

      assert(helpers.start_kong({
        database = strategy,
        plugins = "bundled," .. PLUGIN_NAME,
        nginx_conf = "spec/fixtures/custom_nginx.template",
      }, nil, nil, fixtures))
    end)

    lazy_teardown(function()
      helpers.stop_kong()
    end)


    it("rejects a response that does not verify against the configured anchors", function()
      if not openssl_available then
        return pending("openssl CLI not available")
      end

      local output = s_client_status("stapled.test")
      assert.matches("no response sent", output, nil, true)
      assert.logfile().has.line("OCSP response validation failed", true, 5)
    end)

  end)

end
