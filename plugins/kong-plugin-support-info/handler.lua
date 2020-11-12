
local SupportInfoHandler = {
  PRIORITY = 10,
  VERSION = "0.1.0",
}


function SupportInfoHandler:access(conf)
  -- check if preflight request and whether it should be authenticated
  if not conf.run_on_preflight and kong.request.get_method() == "OPTIONS" then
    return
  end

  kong.log.debug("This is a debug message")

end


return SupportInfoHandler
