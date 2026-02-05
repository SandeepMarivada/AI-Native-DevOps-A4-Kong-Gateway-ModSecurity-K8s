-- Schema definition for Request Enrichment Plugin
-- Defines configuration options and validation rules

local typedefs = require "kong.db.schema.typedefs"

return {
  name = "request-enrichment",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { add_security_headers = {
              type = "boolean",
              default = true,
              description = "Add security headers (X-Content-Type-Options, X-Frame-Options)"
            }
          },
          { log_request_body = {
              type = "boolean",
              default = false,
              description = "Log request body in structured logs (use with caution)"
            }
          },
          { custom_header_prefix = {
              type = "string",
              default = "X-Kong",
              description = "Prefix for custom headers"
            }
          },
        },
      },
    },
  },
}
