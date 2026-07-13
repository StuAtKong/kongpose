-- Integration tests for the fail-open paths: no OCSP responder in the
-- certificate, negative caching of fetch failures, wildcard SNI
-- resolution, and stepping aside for SNIs without a dynamic certificate.
--
-- The happy path (a real staple from a mock responder) lives in
-- 03-responder_spec.lua.

local helpers = require "spec.helpers"

local PLUGIN_NAME = "ocsp-stapling"

-- self-signed, no authorityInfoAccess extension -> every OCSP fetch fails
-- SANs: no-aia.test, *.wild.test; valid for 100 years
local NOAIA_CERT = [[
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

local NOAIA_KEY = [[
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDQ4Bp7FIBCiqBi
aMDWTX9sVs4AwlG3+i7w68E47uaOZrcd/a+kzXu3UyyRg9s6eF8q5smJ3770lz/2
Tj3V6W7ZZ9yJ5AjgrftFprnfg92Ig8Du6TQo17hd4WWH1SmUFh6+MkIc9f0qYdNK
LN3Tvk1vr4R2JWWsCbKOxGRvjLKuRHa7DSBwRYoCqi2FgRtTYAmuqOEonaetRRfH
pAPWEPT+VkmVuQjXUdjsWjolSPi3WtZLSFKDQXh0Xk21+9vGfAJ1e1EKoWEY0osj
jKmQrW8QieBDb09B2sk3TLmAKjSJQX3kCdSy5Edx085L7X4QGiKw2fMW6GXyn3qF
Gr/ygiYfAgMBAAECggEACK23C/QfHCSsY0pc8MqJh9PXfVqVkKJZfvMctSPf+ny0
EQ/wU1WiVUykZmtnGXfU5HBwYUUlpv39z1sS4KdxTqEtHaGW6NbxwMQbpvjQpJJs
2sBfxW6pH2V1FX662odMwbRO4OsrmK413DgfA2Q9zW0qgMou/kXs4FeyoJvk9K6a
RQbISQ0+aOqnfW1pzfhHz3LbvD120BrU2TVOMhpWRQP13DGKQ5SuRfbve4HvhK1D
ODRQo1wafZ6xvVGiOHItNOiY4rBbytkaIzaXBybYbkOhMQOfmdNN2IHYcMo4kky0
FdzP/Vlu+CxO0vFnd3zZVoDVGwDfvGEjkLEysh1gmQKBgQDVU+yGQBSKDWLq0xQq
26V/HvzZ5T1/FDPI9c9jw3hZttfWobYXiKCqm+MvwKa3PH7hj8hHJRIUVf+Ym512
VpG2xUHCL4oP0GVFHNBdgI/jp2/ViKb31df06rze+ICq/1KDUNXzQz8rIWfSOIZW
NzkJyyYAwI+Is5K1Kw1E9NWc5QKBgQD6qC4cacWvv8dE8hUDtFwT8OnfTEnHPW/7
/Vg0882wfkhPBn6fOMrENLYU+ZtL257DPLgXbqlvbSLhefIirgVngi0q5GAiEYhZ
1WdhPYk61I3TA0jlDwpJjV3X1npO605d5QEggRd+4LUIpmtZBtKKnv0IQgrDXl5J
ROv5mSqKswKBgCLp914JgtMNWdEg9r4E8NMbWTq4QBZaUhdj06t6RGo6eJzSHqE/
ZTxHAym/mAmJRyLXi2nJcWoOoSRy45SImpSVOCv159yquMhU7O1Aq0wRDUafdOQ/
BXc6K+s6NKTH4NNJGZsUuHPwpbNMOQBHTXiC3RdmbJds/GfWQfe1MnjZAoGBANhT
p6AsBUod+KvfRhWxZjprlFx8abxDoM9ZIfRpad7lziAt2cAu8oiNeYv2tHmurIGR
eMv4XNDm3tC8PyaBC/b+WV8IRJOCkCv/yr4YrsQQR+qSjinqZhV+pTwvRdWwrSzK
BMP5xb5hzrwNbN4jzjeG6Zhj7wgX/MW9bu82qomTAoGAeWVKJpuDY2Ph2UhJt5Le
rVjouF8/i4WLn1R2gVtHH4mPSuQt2slujhCc+MqwlZd6x2UaNYNoXcwUTkk6tAEY
5eG94DdtFtmPb/0CwKevnHRX9Gow+HEFnqHov7qTsg4PPV3pcVqg/k2blyr8TX0W
7Kq30u2Vgua22T1+FdHSJqE=
-----END PRIVATE KEY-----
]]


local function count_log_lines(needle)
  local path = helpers.test_conf.prefix .. "/logs/error.log"
  local f = io.open(path, "r")
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


-- open a TLS connection with the given SNI, drive one request, close.
-- the request itself 404s (no routes configured); we only care that the
-- handshake -> certificate phase ran.
local function handshake(sni)
  local client = helpers.proxy_ssl_client(5000, sni)
  local res = client:get("/", { headers = { host = sni } })
  assert.is_truthy(res)
  client:close()
end


for _, strategy in helpers.each_strategy() do

  describe(PLUGIN_NAME .. ": (integration, fail-open) [#" .. strategy .. "]", function()

    lazy_setup(function()
      local bp = helpers.get_db_utils(strategy,
                                      { "certificates", "snis", "plugins" },
                                      { PLUGIN_NAME })

      local cert = bp.certificates:insert({
        cert = NOAIA_CERT,
        key = NOAIA_KEY,
      })

      bp.snis:insert({ name = "no-aia.test", certificate = { id = cert.id } })
      bp.snis:insert({ name = "*.wild.test", certificate = { id = cert.id } })

      -- prewarm off so the handshake path itself is what fetches (and
      -- fails); with prewarm on, startup would consume the first failure
      bp.plugins:insert({
        name = PLUGIN_NAME,
        config = { prewarm = false },
      })

      assert(helpers.start_kong({
        database = strategy,
        plugins = "bundled," .. PLUGIN_NAME,
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong()
    end)


    it("completes the handshake unstapled when the cert has no OCSP responder (fail-open)", function()
      handshake("no-aia.test")
      assert.logfile().has.line("no OCSP responder in certificate", true, 5)
    end)

    it("resolves wildcard SNIs and negative-caches fetch failures", function()
      -- three rapid handshakes against a wildcard-covered name:
      -- the first fetch fails and is negative-cached, so exactly one
      -- fetch error may mention this SNI
      for _ = 1, 3 do
        handshake("first.wild.test")
      end

      helpers.wait_until(function()
        return count_log_lines("OCSP fetch for first.wild.test failed") == 1
      end, 5)

      -- and it stays at exactly one
      assert.equal(1, count_log_lines("OCSP fetch for first.wild.test failed"))
    end)

    it("steps aside for SNIs with no dynamic certificate", function()
      handshake("unknown.test")

      -- the plugin must not have touched this SNI at all
      assert.equal(0, count_log_lines("unknown.test"))
    end)

  end)

end
