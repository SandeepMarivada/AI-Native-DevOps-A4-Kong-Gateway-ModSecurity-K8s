-- Custom Kong Plugin: Request Enrichment
-- Implements: Custom request/response header injection + Structured request logging
-- Author: Sandeep M
-- Version: 1.0.0

local kong = kong
local ngx = ngx

local RequestEnrichmentHandler = {
  VERSION = "1.0.0",
  PRIORITY = 1000, -- Execute after auth plugins (>1000) but before response
}

-- Access phase: Add custom headers to upstream request + structured logging
function RequestEnrichmentHandler:access(conf)
  -- Get request metadata
  local request_id = kong.request.get_header("X-Request-ID") or ngx.var.request_id
  local client_ip = kong.client.get_forwarded_ip()
  local method = kong.request.get_method()
  local path = kong.request.get_path()
  local user_agent = kong.request.get_header("User-Agent") or "unknown"
  
  -- Add custom headers to upstream request
  kong.service.request.set_header("X-Kong-Request-ID", request_id)
  kong.service.request.set_header("X-Kong-Client-IP", client_ip)
  kong.service.request.set_header("X-Kong-Request-Time", tostring(ngx.now()))
  kong.service.request.set_header("X-Forwarded-By", "Kong-Custom-Plugin/1.0.0")
  
  -- Structured request logging (JSON format)
  kong.log.info("Request processed by custom plugin: ", {
    request_id = request_id,
    method = method,
    path = path,
    client_ip = client_ip,
    user_agent = user_agent,
    timestamp = ngx.now(),
    plugin = "request-enrichment"
  })
end

-- Header filter phase: Add custom response headers
function RequestEnrichmentHandler:header_filter(conf)
  -- Add response headers for tracking
  kong.response.set_header("X-Kong-Response-Time", tostring(ngx.now()))
  kong.response.set_header("X-Powered-By", "Kong-Gateway-OSS-3.4")
  kong.response.set_header("X-Custom-Plugin", "request-enrichment-v1.0.0")
  
  -- Security header (optional)
  if conf.add_security_headers then
    kong.response.set_header("X-Content-Type-Options", "nosniff")
    kong.response.set_header("X-Frame-Options", "DENY")
  end
end

-- Body filter phase: Log response metadata
function RequestEnrichmentHandler:body_filter(conf)
  local ctx = kong.ctx.plugin
  if not ctx.logged then
    local status = kong.response.get_status()
    local request_id = kong.request.get_header("X-Request-ID") or ngx.var.request_id
    
    -- Log response completion
    kong.log.info("Response completed: ", {
      request_id = request_id,
      status_code = status,
      response_time = ngx.now(),
      plugin = "request-enrichment"
    })
    
    ctx.logged = true
  end
end

return RequestEnrichmentHandler
