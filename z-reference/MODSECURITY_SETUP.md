# ModSecurity Integration with Kong Gateway

## Overview
This document describes the ModSecurity Web Application Firewall (WAF) integration with Kong Gateway for DDoS protection and web application security.

## Architecture
- **Kong Gateway**: v3.4 running on OpenResty 1.21.4.1
- **ModSecurity**: v3 (libmodsecurity3) compiled from source
- **ModSecurity-nginx Connector**: Dynamic module integrated with OpenResty
- **OWASP Core Rule Set**: v3.3.4 (excluding GeoIP rules)

## What Was Implemented

### 1. Custom Kong Docker Image
Built a custom Kong image (`kong-modsecurity:3.4`) that includes:
- ModSecurity v3 library compiled from source
- ModSecurity-nginx connector as a dynamic nginx module
- OWASP Core Rule Set 3.3.4 for threat protection
- All necessary dependencies (PCRE, OpenSSL, libxml2, libcurl)

### 2. ModSecurity Configuration
- **Engine Mode**: `SecRuleEngine On` (actively blocking threats)
- **Rule Set**: OWASP CRS 3.3.4 (IP reputation rules excluded due to lack of GeoIP support)
- **Configuration Location**: `/etc/modsecurity/main.conf`
- **Module Load**: `/usr/local/kong/nginx-includes/modsec_load.conf`

### 3. Kong Integration
Kong environment variables configured:
```bash
KONG_NGINX_MAIN_INCLUDE="/usr/local/kong/nginx-includes/modsec_load.conf"
KONG_NGINX_PROXY_MODSECURITY="on"
KONG_NGINX_PROXY_MODSECURITY_RULES_FILE="/etc/modsecurity/main.conf"
```

## Protection Features

### 1. XSS (Cross-Site Scripting) Protection
Blocks malicious JavaScript injection attempts:
```bash
# Blocked Request
GET /health?test=<script>alert('xss')</script>
# Response: 403 Forbidden
```

### 2. SQL Injection Protection
Detects and blocks SQL injection patterns:
```bash
# Blocked Request
GET /health?id=1' OR '1'='1
# Response: 403 Forbidden
```

### 3. Common Attack Patterns
OWASP CRS protects against:
- Command injection
- Path traversal attacks
- Remote file inclusion
- Protocol attacks
- Application attacks (PHP, Java, Node.js)
- Session fixation
- HTTP protocol violations
- Malicious user agents/bots

## Testing Results

### Successful Blocks:
1. **XSS Attack**: ✅ Blocked with 403
2. **SQL Injection**: ✅ Blocked with 403
3. **Legitimate Traffic**: ✅ Passed through successfully

### Test Commands:
```bash
# Test XSS blocking
kubectl run test-modsec --image=curlimages/curl -n assignment-4 --restart=Never --rm -i -- \
  curl -v "http://kong-kong-proxy:80/health?test=<script>alert('xss')</script>"

# Test SQL injection blocking
kubectl run test-sqli --image=curlimages/curl -n assignment-4 --restart=Never --rm -i -- \
  curl -v -G --data-urlencode "id=1' OR '1'='1" http://kong-kong-proxy:80/health

# Test legitimate traffic
kubectl run test-legitimate --image=curlimages/curl -n assignment-4 --restart=Never --rm -i -- \
  curl -s http://kong-kong-proxy:80/health
```

## Deployment Instructions

### 1. Build the Image
```bash
minikube image build -t kong-modsecurity:3.4 -f kong/Dockerfile .
```

### 2. Update Kong Deployment
```bash
# Set environment variables
kubectl set env deployment/kong-kong -n assignment-4 \
  KONG_NGINX_MAIN_INCLUDE="/usr/local/kong/nginx-includes/modsec_load.conf" \
  KONG_NGINX_PROXY_MODSECURITY="on" \
  KONG_NGINX_PROXY_MODSECURITY_RULES_FILE="/etc/modsecurity/main.conf"

# Restart Kong pods
kubectl delete pod -n assignment-4 -l app.kubernetes.io/name=kong
```

### 3. Verify Deployment
```bash
# Check pod status
kubectl get pods -n assignment-4

# Check Kong logs
kubectl logs -n assignment-4 -l app.kubernetes.io/name=kong
```

## Comparison with Option 3 (CrowdSec)

### Why ModSecurity was chosen:
1. **Native Integration**: ModSecurity integrates directly with nginx/OpenResty at the module level
2. **Mature Solution**: OWASP CRS is battle-tested and widely adopted
3. **No External Dependencies**: No need for separate LAPI service
4. **Better Kong Compatibility**: Works seamlessly with Kong's nginx base
5. **Proven Track Record**: Industry standard for WAF protection

### CrowdSec Issues Encountered:
1. Official Kong plugin repository doesn't exist (404 error)
2. Community plugin incompatible with Kong's architecture
3. Requires separate LAPI service deployment
4. Additional complexity for decision synchronization

## File Structure
```
kong/
├── Dockerfile                    # Custom Kong image with ModSecurity
└── kong.yaml                     # Kong declarative configuration

k8s/
├── deployment.yaml               # User service deployment
└── kong-modsecurity-config.yaml  # ModSecurity configuration (reference)
```

## Security Considerations

### Current Setup:
- ✅ ModSecurity engine actively blocking threats
- ✅ OWASP CRS 3.3.4 rules enabled (except GeoIP)
- ✅ XSS protection active
- ✅ SQL injection protection active
- ✅ Protocol attack protection active

### Production Recommendations:
1. **Enable Logging**: Configure ModSecurity audit logging for forensics
2. **Tune Rules**: Adjust CRS rules based on application false positives
3. **Add GeoIP**: Compile ModSecurity with MaxMind GeoIP support for IP reputation
4. **Monitor Performance**: Track latency impact of WAF inspection
5. **Regular Updates**: Keep OWASP CRS rules up to date

## Troubleshooting

### Common Issues:

1. **Module Load Failure**
   - Check: `/usr/local/lib/ngx_http_modsecurity_module.so` exists
   - Verify: `KONG_NGINX_MAIN_INCLUDE` points to correct path

2. **Configuration Parse Errors**
   - Check: ModSecurity rules syntax in `/etc/modsecurity/main.conf`
   - Verify: OWASP CRS files exist in `/usr/local/owasp-modsecurity-crs/`

3. **GeoIP Errors**
   - Solution: Exclude `REQUEST-910-IP-REPUTATION.conf` from rules
   - Alternative: Recompile ModSecurity with GeoIP support

### Viewing Logs:
```bash
# Kong error logs
kubectl logs -n assignment-4 -l app.kubernetes.io/name=kong | grep modsecurity

# ModSecurity audit logs (if enabled)
kubectl exec -n assignment-4 deployment/kong-kong -- cat /var/log/modsec_audit.log
```

## Performance Impact

### Expected Overhead:
- **Latency**: +2-10ms per request (depending on rule complexity)
- **CPU**: +10-20% (varies with traffic patterns)
- **Memory**: +50-100MB per worker process

### Optimization Tips:
1. Reduce rule complexity by disabling unused rule sets
2. Use SecRuleRemoveById to exclude specific rules
3. Enable SecRuleEngine DetectionOnly for testing before enforcement
4. Adjust worker process count based on traffic volume

## References

- [ModSecurity GitHub](https://github.com/SpiderLabs/ModSecurity)
- [ModSecurity-nginx Connector](https://github.com/SpiderLabs/ModSecurity-nginx)
- [OWASP Core Rule Set](https://github.com/coreruleset/coreruleset)
- [Kong Documentation](https://docs.konghq.com/)
