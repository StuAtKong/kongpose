local PLUGIN_NAME = "ocsp-stapling"

local validate
do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins." .. PLUGIN_NAME .. ".schema")

  function validate(config)
    return validate_entity(config, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (schema)", function()

  it("accepts an empty config and fills defaults", function()
    local entity, err = validate({})
    assert.is_nil(err)
    assert.is_truthy(entity)
    assert.equal(3600, entity.config.cache_ttl)
    assert.equal(5000, entity.config.http_timeout)
    assert.equal(300, entity.config.cert_cache_ttl)
    assert.equal(30, entity.config.failure_ttl)
    assert.equal("kong", entity.config.shm_name)
    assert.is_true(entity.config.prewarm)
    -- unset optional fields come back as ngx.null from schema processing
    assert.is_true(entity.config.ca_certificates == nil
                   or entity.config.ca_certificates == ngx.null)
    assert.is_true(entity.config.trusted_certificate == nil
                   or entity.config.trusted_certificate == ngx.null)
  end)

  it("accepts prewarm = false", function()
    local entity, err = validate({ prewarm = false })
    assert.is_nil(err)
    assert.is_false(entity.config.prewarm)
  end)

  it("accepts a custom shm_name", function()
    local entity, err = validate({ shm_name = "ocsp_stapling" })
    assert.is_nil(err)
    assert.equal("ocsp_stapling", entity.config.shm_name)
  end)

  it("accepts ca_certificates as an array of UUIDs", function()
    local entity, err = validate({
      ca_certificates = {
        "e61307c4-eaf1-4b15-808e-38d52acddf0d",
        "e349dc07-a5b6-4480-a816-6ea64d6bf101",
      },
    })
    assert.is_nil(err)
    assert.equal(2, #entity.config.ca_certificates)
  end)

  it("rejects a non-UUID in ca_certificates", function()
    local entity, err = validate({ ca_certificates = { "not-a-uuid" } })
    assert.is_nil(entity)
    assert.is_truthy(err)
  end)

  it("accepts ca_certificates and trusted_certificate together", function()
    local entity, err = validate({
      ca_certificates = { "e61307c4-eaf1-4b15-808e-38d52acddf0d" },
      trusted_certificate = "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
    })
    assert.is_nil(err)
    assert.is_truthy(entity)
  end)

  it("accepts allowed_responders as hostnames and URLs", function()
    local entity, err = validate({
      allowed_responders = { "ocsp.example.com", "http://ocsp2.example.com:8080" },
    })
    assert.is_nil(err)
    assert.equal(2, #entity.config.allowed_responders)
  end)

  it("rejects an empty string in allowed_responders", function()
    local entity, err = validate({ allowed_responders = { "" } })
    assert.is_nil(entity)
    assert.is_truthy(err)
  end)

  it("rejects an empty allowed_responders array", function()
    -- an empty list would read as locked-down while behaving as allow-all
    local entity, err = validate({ allowed_responders = {} })
    assert.is_nil(entity)
    assert.is_truthy(err)
  end)

  it("rejects cache_ttl of zero", function()
    local entity, err = validate({ cache_ttl = 0 })
    assert.is_nil(entity)
    assert.is_truthy(err)
  end)

  it("rejects a negative http_timeout", function()
    local entity, err = validate({ http_timeout = -1 })
    assert.is_nil(entity)
    assert.is_truthy(err)
  end)

  it("rejects failure_ttl of zero", function()
    local entity, err = validate({ failure_ttl = 0 })
    assert.is_nil(entity)
    assert.is_truthy(err)
  end)

end)
