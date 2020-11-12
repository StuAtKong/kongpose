local inspect = require "inspect"
local kong = kong

return {
  ["/healthcheck/report"] = {
      GET = function(self)

     function os.capture(cmd, raw)
       local f = assert(io.popen(cmd, 'r'))
       local s = assert(f:read('*a'))
       f:close()
       if raw then return s end
       s = string.gsub(s, '^%s+', '')
       s = string.gsub(s, '%s+$', '')
       s = string.gsub(s, '[\n\r]+', ' ')
       return s
     end

      --local r = ngx.location.capture "/nginx_status"
      --if r.status ~= 200 then
        --kong.log.err(r.body)
        --return kong.response.exit(500, { message = "An unexpected error happened" })
      --end


         local response_body = {
           version = kong.version,
           worker_processes_kong = kong.configuration.nginx_worker_processes,
           worker_processes_os = os.capture("ps aux|grep '[w]orker process'", true)
         }

         --kong.log.debug(inspect(kong.configuration))

         -- Get Workspace info
         -- local workspaces = {}
         -- local n = 0
         -- for ws, err in kong.db.workspaces:each() do
           -- if err then
             -- kong.log.warn("failed to get count of workspaces: ", err)
             -- return nil
           -- end
           -- workspaces
           -- n = n + 1
         -- end

         -- response_body[workspace] = {count=n}

         return kong.response.exit(200, {message = response_body})
      end
  },
}
