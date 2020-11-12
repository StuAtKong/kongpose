local healthcheck_schema = {}

local kong = kong

return {
  ["/healthcheck/report"] = {
      GET = function(self)
         kong.log.debug ("Test admin api")
         return kong.response.exit(200, {message = "this is good"})
      end
  },
}
