local typedefs = require "kong.db.schema.typedefs"

return {
  name = "support-info",
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          {
            report = {
              type = "record",
              fields = {
                { license = { type = "boolean", default = true, required = true } },
              },
            },
          },
        },
      },
    },
  },
}
