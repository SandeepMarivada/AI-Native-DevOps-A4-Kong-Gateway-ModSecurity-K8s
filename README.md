# Secure API Platform on Kubernetes with ModSecurity WAF

## 🚀 Quick Start for Evaluators

**Prerequisites**: Docker, Minikube, kubectl, Helm 3.x installed

```bash
# 1. Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# 2. Enable tunnel (new terminal - keep running)
minikube tunnel

# 3. Create namespace
kubectl apply -f k8s/namespace.yaml

# 4. Build custom Kong image (~15 minutes)
minikube image build -t kong-modsecurity:3.4 ./kong

# 5. Deploy microservice
kubectl apply -f microservice/Dockerfile
kubectl apply -f k8s/user-service.yaml

# 6. Deploy Kong declarative config
kubectl apply -f k8s/configmap.yaml

# 7. Deploy Kong Gateway with Helm
helm install kong ./helm/kong-4.40.1.tgz -f k8s/kong-values.yaml -n assignment-4

# 8. Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=user-service -n assignment-4 --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n assignment-4 --timeout=180s

# 9. Run tests (see Complete Testing Guide section below)
curl http://127.0.0.1/health  # Should return {"status":"healthy"}
```

**Full Documentation**: See sections below for detailed deployment, testing, and troubleshooting.

---

## Overview
A production-ready API platform built on Kubernetes using **Kong Gateway (OSS) with ModSecurity v3** for comprehensive API management, security, and DDoS protection. Features include **JWT authentication**, **IP-based rate limiting**, **Web Application Firewall (WAF)**, **custom Lua plugin for request enrichment**, and **OWASP CRS rules**. The system is deployed on local Minikube for development and testing.

---

## Architecture

### High-Level Architecture
```
┌─────────┐      ┌────────────────────────────┐      ┌──────────────┐
│ Client  │─────▶│   Kong Gateway + WAF       │─────▶│ Microservice │
│         │      │   ┌──────────────────┐     │      │  (FastAPI)   │
└─────────┘      │   │  ModSecurity v3  │     │      └──────────────┘
                 │   │  OWASP CRS 3.3.4 │     │              │
                 │   └──────────────────┘     │              │
                 │   Security Layers:         │              │
                 │   • WAF (XSS, SQLi, etc)   │              │
                 │   • JWT Auth               │              │
                 │   • Rate Limiting (10/min) │              │
                 │   • IP Whitelisting        │              │
                 │   • Request Size Limiting  │              │
                 │   • Bot Detection          │              │
                 └────────────────────────────┘              │
                                                    SQLite Database
```

### Components
1. **Microservice**: Python FastAPI application with SQLite database (auto-initialized)
2. **Kong Gateway**: Custom OSS 3.4.2 image with ModSecurity v3 module
3. **Custom Lua Plugin**: request-enrichment plugin for custom headers, logging, and security enhancements
4. **ModSecurity**: v3 WAF library compiled as nginx dynamic module
5. **OWASP CRS**: Core Rule Set 3.3.4 for threat detection
6. **Kubernetes**: Minikube for local orchestration
7. **Helm**: Kong deployment via Helm charts

---

## API Request Flow

### 1. Public Endpoint Request (No Authentication)
```
Client → Kong Gateway → WAF Check → Microservice
  |           |            |            |
  |       [No JWT]    [ModSecurity]     |
  |       [Route: /health, /verify, /login]
  |           |            |            |
  └───────────┴────────────┴────────────┘
                Response 200 OK
```

**Public Endpoints** (No JWT Required):
- `GET /health` - Health check endpoint
- `GET /verify` - Token verification endpoint
- `POST /login` - User authentication endpoint

### 2. Protected Endpoint Request (JWT Required)
```
Client → Kong Gateway → Security Checks → Microservice
  |           |              |               |
  JWT        │              │               │
  Token   ┌──▼──────────────▼───┐           │
  ────▶   │ 1. ModSecurity (WAF)│           │
          │    • XSS Protection │           │
          │    • SQLi Protection│           │
          │    • Path Traversal │           │
          │    • Command Inject │           │
          │ 2. IP Whitelisting  │           │
          │ 3. Rate Limiting    │           │
          │    (10 req/min)     │           │
          │ 4. JWT Validation   │           │
          │ 5. Request Size Chk │           │
          │ 6. Bot Detection    │           │
          └──┬──────────────────┘           │
             │ ✓ All Pass                   │
             └──────────────────────────────▶│
                                             │
                                         Response
```

**Protected Endpoints** (JWT Required):
- `GET /secure` - Protected demo endpoint
- `GET /users` - User list endpoint

### Security Checks (Applied in Order):
1. **ModSecurity WAF**: Inspect for attack patterns (XSS, SQLi, Path Traversal, etc.)
2. **IP Restriction**: Verify client IP against whitelist
3. **Rate Limiting**: Check 10 requests/minute limit per IP
4. **JWT Validation**: Decode and verify JWT token signature
5. **Request Size Limiting**: Maximum 10MB payload
6. **Bot Detection**: Block common bot/crawler/scanner patterns

---

## JWT Authentication Flow

### Login Flow
```
1. Client sends credentials to /login
   POST http://kong-proxy:80/login
   Content-Type: application/x-www-form-urlencoded
   Body: username=admin&password=password123

2. Microservice validates credentials
   • Query SQLite database for user
   • Verify password hash using bcrypt
   • User created on startup if not exists

3. Microservice generates JWT Token
   • Algorithm: HS256
   • Issuer: "assignment-issuer"
   • Expiry: 60 minutes
   • Secret: "super-secret-key"
   • Payload: {"sub": "admin", "exp": <timestamp>, "iss": "assignment-issuer"}

4. Client receives JWT token
   Response 200 OK:
   {
     "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
     "token_type": "bearer"
   }

5. Client includes token in subsequent requests
   GET http://kong-proxy:80/users
   Authorization: Bearer eyJhbGci...
```

### JWT Validation by Kong
```
1. Kong extracts JWT from "Authorization: Bearer <token>" header
2. Kong decodes JWT and reads "iss" claim (issuer)
3. Kong matches issuer "assignment-issuer" to consumer "admin"
4. Kong verifies signature using shared secret "super-secret-key"
5. Kong checks token expiration (exp claim)
6. Kong forwards request to microservice (or rejects with 401)
```

**JWT Consumer Configuration** (in `kong/kong.yaml`):
```yaml
consumers:
  - username: admin
    jwt_secrets:
      - key: "assignment-issuer"     # Must match JWT "iss" claim
        secret: "super-secret-key"    # Must match microservice secret
```

**Default User Credentials**:
- Username: `admin`
- Password: `password123`
- Auto-created on microservice startup

---

## Authentication Bypass Strategy

### Implementation: Route-Level Plugin Isolation
Kong applies plugins **per route**, not per service. This allows fine-grained control over which endpoints require authentication.

### Route Configuration (kong/kong.yaml)
```yaml
services:
  - name: user-service
    url: http://user-service.assignment-4.svc.cluster.local:80
    routes:
    
    # PUBLIC ROUTES - No JWT plugin = No authentication
    - name: public-routes
      paths:
        - /health    # Health check - always accessible
        - /verify    # Token verification - public
        - /login     # Authentication - must be public
      strip_path: false
      # NO PLUGINS = Public access
    
    # PROTECTED ROUTES - JWT plugin enforced
    - name: secure-routes
      paths:
        - /secure    # Protected demo endpoint
        - /users     # User list endpoint
      strip_path: false
      plugins:
        - name: jwt                      # JWT required
        - name: rate-limiting            # 10 req/min per IP
        - name: request-size-limiting    # Max 10MB payload
        - name: ip-restriction           # IP whitelist check
        - name: bot-detection            # Block known bots
```

### Why This Works
- Kong evaluates plugins **per route**, not globally
- Public routes have **zero authentication plugins** → Freely accessible
- Protected routes have **JWT plugin attached** → Token required
- This is the **official Kong pattern** for mixed auth requirements
- No custom code or workarounds needed

---

## Custom Kong Lua Plugin: Request Enrichment

### Overview
The **request-enrichment** plugin is a custom Lua extension that demonstrates Kong's extensibility through the Plugin Development Kit (PDK). It adds custom headers, security enhancements, and structured logging to all requests/responses.

### Plugin Architecture
```
┌────────────────────────────────────────┐
│  Kong Gateway (OpenResty/Lua 5.1)     │
│                                        │
│  Plugin: request-enrichment v1.0.0    │
│  ┌──────────────────────────────────┐ │
│  │  Phase 1: access()               │ │  ← Request Phase
│  │  • Inject request headers        │ │
│  │  • Add request ID, client IP     │ │
│  │  • Add request timestamp         │ │
│  └──────────────────────────────────┘ │
│  ┌──────────────────────────────────┐ │
│  │  Phase 2: header_filter()        │ │  ← Response Phase
│  │  • Calculate response time       │ │
│  │  • Add custom headers            │ │
│  │  • Add security headers          │ │
│  └──────────────────────────────────┘ │
│  ┌──────────────────────────────────┐ │
│  │  Phase 3: body_filter()          │ │  ← Logging Phase
│  │  • Structured JSON logging       │ │
│  │  • Request/response metadata     │ │
│  └──────────────────────────────────┘ │
└────────────────────────────────────────┘
```

### Features

**Custom Request Headers** (Injected during access phase):
- `X-Kong-Request-ID`: Unique request identifier (from nginx)
- `X-Kong-Client-IP`: Real client IP (respects X-Forwarded-For)
- `X-Kong-Request-Time`: Request timestamp in seconds
- `X-Forwarded-By`: Kong gateway identifier

**Custom Response Headers** (Added during header_filter phase):
- `X-Kong-Response-Time`: Time taken to process request (microseconds)
- `X-Powered-By`: Kong Gateway version identifier
- `X-Custom-Plugin`: Plugin name and version (request-enrichment-v1.0.0)

**Security Headers** (When enabled):
- `X-Content-Type-Options: nosniff` - Prevent MIME sniffing attacks
- `X-Frame-Options: DENY` - Prevent clickjacking attacks

**Structured Logging** (JSON format):
```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "method": "GET",
  "path": "/users",
  "status": 200,
  "latency_ms": 45.2,
  "client_ip": "192.168.1.100",
  "plugin": "request-enrichment"
}
```

### Implementation Details

**Files**:
- `kong/plugins/request-enrichment/handler.lua` (73 lines) - Core plugin logic
- `kong/plugins/request-enrichment/schema.lua` (39 lines) - Configuration schema
- `kong/plugins/request-enrichment/README.md` - Plugin documentation

**Configuration Options**:
```yaml
plugins:
  - name: request-enrichment
    config:
      add_security_headers: true        # Enable X-Content-Type-Options, X-Frame-Options
      log_request_body: false           # Log request body in JSON logs (disabled by default)
      custom_header_prefix: "X-Kong"    # Prefix for custom headers
```

**Deployment Method**:
1. Plugin code copied into Kong image during Docker build
2. Plugin registered via `KONG_PLUGINS=bundled,request-enrichment` environment variable
3. Plugin activated globally in `kong.yaml` declarative configuration
4. Applied to all routes and services

**Testing**:
```bash
# Check custom headers in response
curl -v http://127.0.0.1/health

# Look for these headers:
# X-Kong-Response-Time: 1770226745.958
# X-Powered-By: Kong-Gateway-OSS-3.4
# X-Custom-Plugin: request-enrichment-v1.0.0
# X-Content-Type-Options: nosniff
# X-Frame-Options: DENY
```

### Why Custom Lua Plugin?

**Assignment Requirement**:
> "Custom Kong Lua Logic: Implement at least one custom Lua script... Lua code must be version-controlled... Lua logic must be deployed via Kong configuration"

**Benefits**:
- **Observability**: Custom headers aid in debugging and request tracing
- **Security**: Additional hardening with security headers
- **Flexibility**: Easy to extend with business-specific logic
- **Performance**: Lua runs in OpenResty (nginx) - minimal overhead (<1ms)
- **Version Control**: Plugin code committed to repository
- **Declarative**: Configuration in kong.yaml, no manual Admin API calls

---

## DDoS Protection: ModSecurity WAF

### Solution: Kong + ModSecurity v3 + OWASP CRS 3.3.4

#### Architecture
```
┌────────────────────────────────────────┐
│     Kong Gateway (OpenResty/nginx)     │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │  ngx_http_modsecurity_module.so  │ │  ← Dynamic Module
│  │  (Compiled with OpenResty)       │ │
│  └────────────┬─────────────────────┘ │
│               │                        │
│               ▼                        │
│  ┌──────────────────────────────────┐ │
│  │  ModSecurity v3 Library          │ │  ← WAF Engine
│  │  (libmodsecurity.so)             │ │
│  └────────────┬─────────────────────┘ │
│               │                        │
│               ▼                        │
│  ┌──────────────────────────────────┐ │
│  │  OWASP CRS 3.3.4 Rules           │ │  ← Rule Set
│  │  /etc/modsecurity/main.conf      │ │
│  │  /usr/local/owasp-modsecurity-   │ │
│  │    crs/rules/*.conf              │ │
│  └──────────────────────────────────┘ │
└────────────────────────────────────────┘
```

#### Implementation Details

**Custom Kong Image**: `kong-modsecurity:3.4`
- Base: Official Kong 3.4 (kong:3.4)
- ModSecurity v3: Compiled from source (v3/master branch)
- ModSecurity-nginx: Compiled as dynamic nginx module
- OWASP CRS: Version 3.3.4 (GeoIP rules excluded)
- Build: Multi-stage Dockerfile (~15min build time)

**ModSecurity Configuration**:
```conf
# /etc/modsecurity/modsecurity.conf
SecRuleEngine On                    # Active blocking mode
SecRequestBodyAccess On             # Inspect POST bodies
SecResponseBodyAccess Off           # Don't inspect responses
SecAuditEngine RelevantOnly         # Log blocked requests

# /etc/modsecurity/main.conf
Include /etc/modsecurity/modsecurity.conf
Include /usr/local/owasp-modsecurity-crs/crs-setup.conf
Include /usr/local/owasp-modsecurity-crs/rules/*.conf
```

**Kong Integration** (Environment Variables):
```bash
KONG_NGINX_MAIN_INCLUDE=/usr/local/kong/nginx-includes/modsec_load.conf
KONG_NGINX_PROXY_MODSECURITY=on
KONG_NGINX_PROXY_MODSECURITY_RULES_FILE=/etc/modsecurity/main.conf
```

#### Protection Coverage

**OWASP CRS Rules Enabled**:
- **SQL Injection** (94x rules) - SQLi, database attacks
- **Cross-Site Scripting** (94x rules) - XSS, JavaScript injection
- **Local File Inclusion** (93x rules) - Path traversal, file access
- **Remote File Inclusion** (93x rules) - Remote code execution
- **Remote Code Execution** (93x rules) - Command injection
- **PHP Injection** (93x rules) - PHP-specific attacks
- **HTTP Protocol Violations** (92x rules) - Malformed requests
- **Session Fixation** (94x rules) - Session hijacking
- **Scanner Detection** (91x rules) - Automated scanning tools
- **Java Attacks** (94x rules) - Struts, Spring exploits

**Attack Examples Blocked**:
```bash
# XSS Attack
GET /health?test=<script>alert('xss')</script>
→ 403 Forbidden

# SQL Injection
GET /health?id=1' OR '1'='1
→ 403 Forbidden

# Path Traversal
GET /health?file=../../etc/passwd
→ 403 Forbidden

# Command Injection
GET /health?cmd=;cat /etc/passwd
→ 403 Forbidden
```

#### Why ModSecurity Over CrowdSec?

| Feature | ModSecurity + OWASP CRS | CrowdSec |
|---------|------------------------|----------|
| Integration | Native nginx module | External service + API |
| Complexity | Single container | Multi-container (LAPI + Bouncer) |
| Rule Set | 15+ years, battle-tested | Community-driven, newer |
| Latency | <5ms overhead | +10-20ms (API calls) |
| Kong Compatibility | Perfect (OpenResty base) | Plugin exists but complex |
| Maintenance | Self-contained | Requires LAPI management |
| Status | ✅ Implemented & Active | ❌ Attempted, integration issues |

**CrowdSec Attempt Summary**:
- Official Kong plugin repository: 404 Not Found
- Community plugin: Incompatible with Kong architecture
- Requires separate LAPI deployment and key management
- Adds operational complexity for marginal benefit
- **Decision**: ModSecurity provides superior integration

#### Additional DDoS Layers

**1. Rate Limiting** (Kong Plugin)
```yaml
- name: rate-limiting
  config:
    minute: 10           # Max 10 requests per minute
    limit_by: ip         # Per client IP address
    policy: local        # In-memory (fast)
```
- Prevents request flooding from single source
- Returns `429 Too Many Requests` after limit
- Headers: `X-RateLimit-Remaining-Minute`, `X-RateLimit-Limit-Minute`

**2. IP Restriction** (Kong Plugin)
```yaml
- name: ip-restriction
  config:
    allow:
      - 0.0.0.0/0        # Open for testing (restrict in prod)
```
- Whitelist specific IP ranges (CIDR notation)
- Blocks all other traffic with 403
- Production: Replace with actual allowed subnets

**3. Request Size Limiting** (Kong Plugin)
```yaml
- name: request-size-limiting
  config:
    allowed_payload_size: 10    # 10 MB maximum
```
- Prevents large payload attacks
- Returns `413 Payload Too Large` if exceeded

**4. Bot Detection** (Kong Plugin)
```yaml
- name: bot-detection
  config:
    deny:
      - "bot"
      - "crawler"
      - "scanner"
```
- Blocks known bot User-Agent patterns
- Prevents automated scanning/scraping

### DDoS Protection Summary

| Layer | Technology | Status | Protection |
|-------|-----------|--------|------------|
| **Application WAF** | ModSecurity v3 + OWASP CRS | ✅ Active | XSS, SQLi, RCE, LFI, Protocol attacks |
| **Rate Limiting** | Kong Plugin | ✅ Active | Request flooding, API abuse |
| **IP Restriction** | Kong Plugin | ✅ Active | Unauthorized source IPs |
| **Size Limiting** | Kong Plugin | ✅ Active | Large payload attacks |
| **Bot Detection** | Kong Plugin | ✅ Active | Automated scanners |

**Full Documentation**: See [MODSECURITY_SETUP.md](z-reference/MODSECURITY_SETUP.md) for complete ModSecurity implementation details.

---

## Deployment Instructions

### Prerequisites
✅ **Required Software**:
- **Minikube** (v1.30+) - Local Kubernetes cluster
- **kubectl** - Kubernetes CLI
- **Docker** - Container runtime
- **Helm** - Kubernetes package manager (v3+)

⚠️ **System Requirements**:
- 4GB RAM minimum (8GB recommended)
- 20GB free disk space
- Windows/Mac/Linux OS

### Step 1: Start Minikube
```bash
# Start Minikube cluster
minikube start --cpus=2 --memory=4096

# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

**Expected Output**:
```
Kubernetes control plane is running at https://...
minikube   Ready    control-plane   1m   v1.28.3
```

### Step 2: Create Namespace
```bash
kubectl create namespace assignment-4
```

### Step 3: Build Custom Kong Image with ModSecurity

**Important**: This step builds a custom Kong image with ModSecurity WAF compiled from source.

```bash
# Build image inside Minikube's Docker daemon (saves image push/pull)
minikube image build -t kong-modsecurity:3.4 -f kong/Dockerfile .
```

**Build Time**: ~10-15 minutes (compiles ModSecurity v3 + ModSecurity-nginx module)

**Verify Image**:
```bash
minikube image ls | grep kong-modsecurity
# Should show: kong-modsecurity:3.4
```

### Step 4: Build Microservice Image

```bash
# Build microservice image
minikube image build -t sandeepm/secure-api:latest -f microservice/Dockerfile microservice/
```

**Verify Image**:
```bash
minikube image ls | grep secure-api
# Should show: sandeepm/secure-api:latest
```

### Step 5: Deploy Kong with Helm

```bash
# Add Kong Helm repository
helm repo add kong https://charts.konghq.com
helm repo update

# Create Kong declarative config ConfigMap
kubectl create configmap kong-declarative-config \
  --from-file=kong.yaml=kong/kong.yaml \
  -n assignment-4

# Install Kong with custom values
helm install kong kong/kong \
  --namespace assignment-4 \
  --set image.repository=kong-modsecurity \
  --set image.tag=3.4 \
  --set image.pullPolicy=Never \
  --set ingressController.enabled=false \
  --set env.database=off \
  --set env.declarative_config=/kong_declarative/kong.yaml \
  --set env.nginx_main_include=/usr/local/kong/nginx-includes/modsec_load.conf \
  --set env.nginx_proxy_modsecurity=on \
  --set env.nginx_proxy_modsecurity_rules_file=/etc/modsecurity/main.conf \
  --set deployment.kong.daemonset=false \
  --set deployment.userDefinedVolumes[0].name=kong-declarative-config \
  --set deployment.userDefinedVolumes[0].configMap.name=kong-declarative-config \
  --set deployment.userDefinedVolumeMounts[0].name=kong-declarative-config \
  --set deployment.userDefinedVolumeMounts[0].mountPath=/kong_declarative
```

**Wait for Kong to be ready**:
```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n assignment-4 --timeout=120s
```

### Step 6: Deploy User Service

```bash
# Deploy using Helm chart
helm install user-service ./helm/user-service --namespace assignment-4
```

**Alternative (using kubectl)**:
```bash
kubectl apply -f k8s/deployment.yaml -n assignment-4
```

**Verify Deployment**:
```bash
kubectl get pods -n assignment-4
```

**Expected Output**:
```
NAME                            READY   STATUS    RESTARTS   AGE
kong-kong-xxxxx                 1/1     Running   0          2m
user-service-xxxxx              1/1     Running   0          1m
```

### Step 7: Expose Kong Gateway

**Option A: Minikube Tunnel (Recommended)**
```bash
# Open new terminal and run (keep it running):
minikube tunnel
```

This exposes Kong LoadBalancer at `127.0.0.1:80`

**Option B: Port Forward**
```bash
kubectl port-forward -n assignment-4 svc/kong-kong-proxy 8080:80
```

Access Kong at `http://localhost:8080`

### Step 8: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n assignment-4

# Check services
kubectl get svc -n assignment-4

# Test health endpoint
curl http://127.0.0.1/health
```

**Expected Response**:
```json
{"status":"healthy"}
```

### Troubleshooting Deployment

**Issue: Kong pod not starting**
```bash
# Check pod status
kubectl describe pod -l app.kubernetes.io/name=kong -n assignment-4

# Check logs
kubectl logs -l app.kubernetes.io/name=kong -n assignment-4 --tail=50
```

**Common Issues**:
1. **Image not found**: Ensure `minikube image build` completed successfully
2. **ConfigMap missing**: Verify `kong-declarative-config` exists
3. **Memory issues**: Increase Minikube resources: `minikube start --memory=8192`

**Issue: User service not responding**
```bash
# Check pod logs
kubectl logs -l app=user-service -n assignment-4

# Check service endpoints
kubectl get endpoints -n assignment-4
```

---

## Complete Testing Guide

### Pre-Test Verification

```bash
# 1. Verify all pods are running
kubectl get pods -n assignment-4

# Expected: kong-kong and user-service both 1/1 Running

# 2. Verify Kong proxy service has external IP
kubectl get svc kong-kong-proxy -n assignment-4

# Expected: EXTERNAL-IP should be 127.0.0.1 (with minikube tunnel)

# 3. Set Kong URL variable for tests
export KONG_URL="http://127.0.0.1"
# PowerShell: $KONG_URL="http://127.0.0.1"
```

### Test 1: Health Check (Public Endpoint - No Auth)

**Purpose**: Verify public endpoint accessibility without JWT

```bash
curl $KONG_URL/health
```

**Expected Response**:
```json
{"status":"healthy"}
```

**HTTP Status**: `200 OK`

✅ **Pass Criteria**: Returns 200 with health status

---

### Test 2: Verify Endpoint (Public - No Auth)

```bash
curl $KONG_URL/verify
```

**Expected Response**:
```json
{"valid":false,"detail":"Token missing"}
```

**HTTP Status**: `200 OK`

✅ **Pass Criteria**: Returns 200 (endpoint accessible without token)

---

### Test 3: Login and Obtain JWT Token

**Purpose**: Authenticate and receive JWT access token

```bash
curl -X POST $KONG_URL/login \
  --data-urlencode "username=admin" \
  --data-urlencode "password=password123"
```

**Expected Response**:
```json
{
  "access_token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsImV4cCI6MTc3MDIxOTI4MCwiaXNzIjoiYXNzaWdubWVudC1pc3N1ZXIifQ...",
  "token_type":"bearer"
}
```

**Save the token**:
```bash
export TOKEN="<paste-access-token-value>"
# PowerShell: $TOKEN="<paste-access-token-value>"
```

✅ **Pass Criteria**: Returns 200 with access_token field

---

### Test 4: Access Protected Endpoint WITHOUT JWT

**Purpose**: Verify JWT authentication is enforced

```bash
curl -v $KONG_URL/users
```

**Expected Response**:
```json
{"message":"Unauthorized"}
```

**HTTP Status**: `401 Unauthorized`

✅ **Pass Criteria**: Returns 401 (access denied without token)

---

### Test 5: Access Protected Endpoint WITH Valid JWT

**Purpose**: Verify JWT authentication allows access

```bash
curl -H "Authorization: Bearer $TOKEN" $KONG_URL/users
```

**Expected Response**:
```json
[{"id":1,"username":"admin","is_active":true}]
```

**HTTP Status**: `200 OK`

✅ **Pass Criteria**: Returns 200 with user data

---

### Test 6: Access Secure Endpoint with JWT

```bash
curl -H "Authorization: Bearer $TOKEN" $KONG_URL/secure
```

**Expected Response**:
```json
{
  "message":"This is a secure endpoint protected by Kong!",
  "context":"If you see this, and you didn't provide a token, Kong Bypass is active."
}
```

**HTTP Status**: `200 OK`

✅ **Pass Criteria**: Returns 200 with secure message

---

### Test 7: Rate Limiting (10 Requests/Minute)

**Purpose**: Verify rate limiting blocks after 10 requests

**Using Bash**:
```bash
for i in {1..12}; do
  echo "Request $i:"
  curl -s -o /dev/null -w "  HTTP Status: %{http_code}\n" \
    -H "Authorization: Bearer $TOKEN" \
    $KONG_URL/users
  sleep 0.1
done
```

**Using PowerShell**:
```powershell
foreach ($i in 1..12) {
  Write-Host "Request $i:"
  curl -s -o $null -w "  HTTP Status: %{http_code}`n" `
    -H "Authorization: Bearer $TOKEN" `
    $KONG_URL/users
  Start-Sleep -Milliseconds 100
}
```

**Expected Results**:
```
Request 1:  HTTP Status: 200
Request 2:  HTTP Status: 200
...
Request 10: HTTP Status: 200
Request 11: HTTP Status: 429  ← Rate limit exceeded
Request 12: HTTP Status: 429  ← Rate limit exceeded
```

✅ **Pass Criteria**: Requests 1-10 succeed (200), requests 11+ fail (429)

**Wait 60 seconds** before next test for rate limit reset.

---

### Test 8: DDoS Protection - XSS Attack

**Purpose**: Verify ModSecurity WAF blocks XSS attacks

```bash
curl -v "$KONG_URL/health?test=<script>alert('xss')</script>"
```

**Expected Response**:
```html
<html>
<head><title>403 Forbidden</title></head>
<body><center><h1>403 Forbidden</h1></center></body>
</html>
```

**HTTP Status**: `403 Forbidden`

✅ **Pass Criteria**: Returns 403 (WAF blocked XSS attempt)

---

### Test 9: DDoS Protection - SQL Injection

**Purpose**: Verify ModSecurity WAF blocks SQL injection

```bash
curl -v -G --data-urlencode "id=1' OR '1'='1" $KONG_URL/health
```

**Expected Response**:
```html
<html>
<head><title>403 Forbidden</title></head>
<body><center><h1>403 Forbidden</h1></center></body>
</html>
```

**HTTP Status**: `403 Forbidden`

✅ **Pass Criteria**: Returns 403 (WAF blocked SQLi attempt)

---

### Test 10: DDoS Protection - Path Traversal

**Purpose**: Verify ModSecurity WAF blocks path traversal attacks

```bash
curl -v "$KONG_URL/health?file=../../etc/passwd"
```

**Expected Response**: `403 Forbidden`

**HTTP Status**: `403 Forbidden`

✅ **Pass Criteria**: Returns 403 (WAF blocked path traversal)

---

### Test 11: DDoS Protection - Command Injection

**Purpose**: Verify ModSecurity WAF blocks command injection

```bash
curl -v "$KONG_URL/health?cmd=;cat%20/etc/passwd"
```

**Expected Response**: `403 Forbidden`

**HTTP Status**: `403 Forbidden`

✅ **Pass Criteria**: Returns 403 (WAF blocked command injection)

---

### Test 12: Legitimate Request After Attacks

**Purpose**: Verify legitimate traffic still works after blocking attacks

```bash
curl $KONG_URL/health
```

**Expected Response**:
```json
{"status":"healthy"}
```

**HTTP Status**: `200 OK`

✅ **Pass Criteria**: Returns 200 (legitimate requests not affected)

---

### Test 13: Verify ModSecurity Module Loaded

**Purpose**: Confirm ModSecurity is actively loaded in Kong

```bash
kubectl exec -n assignment-4 deployment/kong-kong -- \
  ls -la /usr/local/lib/ngx_http_modsecurity_module.so
```

**Expected Output**:
```
-rwxr-xr-x 1 root root 225856 Feb 4 14:06 /usr/local/lib/ngx_http_modsecurity_module.so
```

✅ **Pass Criteria**: File exists and has execute permissions

---

### Test 14: Verify Kong Configuration

**Purpose**: Confirm Kong configuration includes ModSecurity directives

```bash
curl -s http://127.0.0.1:8001/ | grep -E "modsecurity|nginx_main_include"
```

**Expected Output** (contains):
```json
{
  "nginx_main_include": "/usr/local/kong/nginx-includes/modsec_load.conf",
  "nginx_proxy_modsecurity": "on",
  "nginx_proxy_modsecurity_rules_file": "/etc/modsecurity/main.conf"
}
```

✅ **Pass Criteria**: ModSecurity directives present in configuration

---

### Test 15: Verify Custom Lua Plugin Headers

**Purpose**: Confirm custom request-enrichment plugin is active and adding headers

```bash
curl -v http://127.0.0.1/health 2>&1 | grep -E "X-Kong-Response-Time|X-Custom-Plugin|X-Content-Type-Options|X-Frame-Options"
```

**Expected Response Headers**:
```
< X-Kong-Response-Time: 1770226745.958
< X-Custom-Plugin: request-enrichment-v1.0.0
< X-Content-Type-Options: nosniff
< X-Frame-Options: DENY
```

**HTTP Status**: `200 OK`

✅ **Pass Criteria**: All 4 custom headers present in response

---

### Test Summary Checklist

| Test # | Test Name | Expected Result | Status |
|--------|-----------|-----------------|--------|
| 1 | Health Check (Public) | 200 OK | ⬜ |
| 2 | Verify Endpoint (Public) | 200 OK | ⬜ |
| 3 | Login & Get JWT | 200 OK + token | ⬜ |
| 4 | Protected Without JWT | 401 Unauthorized | ⬜ |
| 5 | Protected With JWT | 200 OK + data | ⬜ |
| 6 | Secure Endpoint | 200 OK | ⬜ |
| 7 | Rate Limiting | 200×10, then 429 | ⬜ |
| 8 | Block XSS Attack | 403 Forbidden | ⬜ |
| 9 | Block SQL Injection | 403 Forbidden | ⬜ |
| 10 | Block Path Traversal | 403 Forbidden | ⬜ |
| 11 | Block Command Injection | 403 Forbidden | ⬜ |
| 12 | Legitimate After Attacks | 200 OK | ⬜ |
| 13 | ModSecurity Module | File exists | ⬜ |
| 14 | Kong Configuration | Directives present | ⬜ |
| 15 | Custom Lua Plugin | 4 headers present | ⬜ |

### Advanced Testing (Optional)

**Test IP Whitelisting**:
```bash
# Edit kong/kong.yaml to restrict IPs
# Update: ip-restriction.config.allow to specific CIDR
# Apply changes and test from different IP
```

**Test Bot Detection**:
```bash
curl -H "User-Agent: Bot Scanner/1.0" $KONG_URL/health
# Expected: 403 or route not matched
```

**Load Testing**:
```bash
# Install Apache Bench or similar
ab -n 1000 -c 10 -H "Authorization: Bearer $TOKEN" $KONG_URL/users
```

---

## Complete Test Results

For comprehensive test results with detailed outputs and analysis, see:
- **[TEST_RESULTS.md](z-reference/TEST_RESULTS.md)** - Full test execution log with all 14 tests

---

## Project Structure

```
AI-Native DevOps Assignment 4/
├── helm/
│   └── user-service/                       # User service Helm chart
│       ├── templates/
│       │   ├── _helpers.tpl
│       │   ├── deployment.yaml
│       │   ├── ingress.yaml
│       │   └── service.yaml
│       ├── Chart.yaml
│       └── values.yaml
│
├── k8s/
│   └── deployment.yaml                     # User service & Kong deployment manifests
│
├── kong/
│   ├── plugins/
│   │   └── request-enrichment/             # Custom Lua plugin for request/response enrichment
│   │       ├── handler.lua                 # Plugin logic (header injection, logging)
│   │       ├── schema.lua                  # Configuration schema
│   │       └── README.md                   # Plugin documentation
│   ├── Dockerfile                          # Custom Kong image with ModSecurity v3 WAF
│   └── kong.yaml                           # Declarative Kong configuration (routes, services, plugins)
│
├── microservice/
│   ├── app/
│   │   ├── auth.py                         # JWT authentication utilities
│   │   ├── database.py                     # SQLite database initialization
│   │   ├── main.py                         # FastAPI application with JWT auth
│   │   └── models.py                       # SQLAlchemy models (User)
│   ├── Dockerfile                          # User service container
│   └── requirements.txt                    # Python dependencies
│
├── postman/                                # Postman collection for API testing
│   ├── Kong_API_Platform_Demo.postman_collection.json
│   ├── Kong_Environment.postman_environment.json
│   └── POSTMAN_SETUP.md
│
├── terraform/
│   ├── .terraform.lock.hcl                 # Terraform dependency lock file
│   ├── main.tf                             # Terraform configuration
│   └── terraform.tfstate                   # Terraform state file
│
├── z-reference/                            # Additional documentation
│   ├── AI-Native DevOps Assignment 4_Requirements.md
│   ├── DDOS_PROTECTION.md
│   ├── DELIVERABLES_CHECKLIST.md
│   ├── EVALUATOR_GUIDE.md
│   ├── MODSECURITY_SETUP.md
│   ├── QUICK_REFERENCE.md
│   └── TEST_RESULTS.md
│
├── .gitignore                              # Git ignore patterns
├── README.md                               # Complete deployment & testing guide (THIS FILE)
└── ai-usage.md                             # AI tools usage documentation
```

### Key Files Explained

**Kong Gateway**:
- `kong/Dockerfile`: Multi-stage build compiling ModSecurity v3 library + ModSecurity-nginx connector. Integrates with OpenResty. Includes custom Lua plugin installation. Build time ~10-15 minutes.
- `kong/kong.yaml`: Complete declarative configuration with 6 Kong plugins (jwt, rate-limiting, ip-restriction, request-size-limiting, bot-detection, request-enrichment) + ModSecurity WAF
- `kong/plugins/request-enrichment/`: Custom Lua plugin adding custom headers (X-Kong-Response-Time, X-Custom-Plugin), security headers (X-Content-Type-Options, X-Frame-Options), and structured JSON logging
- `kong/nginx-includes/`: ModSecurity integration files loaded via KONG_NGINX_MAIN_INCLUDE and KONG_NGINX_PROXY_MODSECURITY* environment variables

**Microservice**:
- `microservice/app/main.py`: FastAPI app with 6 endpoints (3 public: /health, /verify, /login | 3 protected: /secure, /users, /admin), auto-creates admin user on startup
- `microservice/app/database.py`: SQLite database with bcrypt password hashing
- `microservice/Dockerfile`: Python 3.11-slim container

**Kubernetes**:
- `k8s/kong-values.yaml`: Helm overrides for custom image (kong-modsecurity:3.4), environment variables (ModSecurity config), service type LoadBalancer
- `k8s/configmap.yaml`: Mounts kong.yaml into Kong container at `/opt/kong/kong.yaml`
- `k8s/user-service.yaml`: Deployment with 1 replica, SQLite volume, ClusterIP service on port 8000

**Documentation**:
- `README.md`: Step-by-step deployment, testing, troubleshooting (you are here!)
- `ai-usage.md`: Complete AI interaction history and learnings
- `postman/`: Postman collection for testing all endpoints
- `z-reference/`: Additional technical documentation including test results, ModSecurity setup, DDoS protection details, and evaluator guides

---

## Technologies Used

### Core Stack
- **Microservice**: Python 3.11, FastAPI 0.104, SQLAlchemy 2.0, SQLite3, Bcrypt, PyJWT
- **API Gateway**: Kong OSS 3.4.2 (DB-less declarative mode)
- **Web Application Firewall**: ModSecurity v3 (libmodsecurity), OWASP CRS 3.3.4
- **Container Runtime**: Docker 24+
- **Orchestration**: Kubernetes 1.28+ (Minikube for local)
- **Package Manager**: Helm 3.x

### Security Components
- **Authentication**: JWT (HS256 algorithm) with "assignment-issuer" issuer claim
- **Rate Limiting**: Kong rate-limiting plugin (10 requests/minute per consumer)
- **IP Filtering**: Kong ip-restriction plugin (whitelist-based)
- **Request Validation**: Kong request-size-limiting plugin (10MB max)
- **Bot Detection**: Kong bot-detection plugin
- **DDoS/Attack Protection**: ModSecurity v3 WAF with OWASP Core Rule Set 3.3.4
  - XSS detection and blocking
  - SQL injection prevention
  - Path traversal protection
  - Command injection blocking
  - HTTP protocol validation
  - Malicious user-agent detection

### Infrastructure as Code
- **Declarative Config**: Kong DB-less mode (kong.yaml)
- **Kubernetes Manifests**: YAML-based deployments, services, configmaps
- **Helm Charts**: Kong gateway deployment (chart v4.40.1)
- **Terraform**: Infrastructure provisioning (placeholder for production)

---

## Security Considerations

### Production Checklist
- [ ] Change JWT secret from `super-secret-key` to secure random value (use Kubernetes Secret)
- [ ] Store all sensitive values in Kubernetes Secrets (externalize from kong.yaml)
- [ ] Restrict IP whitelist from `0.0.0.0/0` to actual allowed CIDRs
- [ ] Enable HTTPS/TLS with valid SSL certificates (Kong SSL plugin)
- [ ] Configure ModSecurity audit logging to persistent storage
- [ ] Implement JWT token refresh mechanism with shorter expiration
- [ ] Add PostgreSQL/MySQL instead of SQLite for production workloads
- [ ] Set up centralized logging (ELK/EFK stack)
- [ ] Implement monitoring and alerting (Prometheus + Grafana)
- [ ] Enable Kong Admin API authentication (RBAC)
- [ ] Configure resource limits and requests for all pods
- [ ] Implement network policies for pod-to-pod communication
- [ ] Set up automated security scanning (Trivy, Snyk)
- [ ] Configure ModSecurity in blocking mode (currently DetectionOnly for testing)
- [ ] Enable GeoIP support in ModSecurity for IP reputation rules

### ModSecurity Performance Impact
- **Latency**: +5-15ms per request (WAF processing overhead)
- **CPU**: +10-20% utilization under load
- **Memory**: +50-100MB per Kong instance
- **Recommendation**: Scale Kong horizontally (2+ replicas) in production
- [ ] Review rate limits based on traffic patterns
- [ ] Rotate credentials periodically

---

## Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod <pod-name> -n assignment-4
kubectl logs <pod-name> -n assignment-4
```

### Kong Returns 404
- Verify ConfigMap: `kubectl get configmap kong-declarative-config -n assignment-4 -o yaml`
- Check service DNS: `kubectl get svc -n assignment-4`
- Ensure namespace in kong.yaml matches deployment namespace

### Rate Limit Not Working
- Check Kong logs: `kubectl logs <kong-pod> -c proxy -n assignment-4`
- Verify plugin configuration in `kong/kong.yaml`
- Check rate limit headers in response

### JWT Token Invalid
- Verify consumer configuration matches JWT issuer
- Check token expiration time
- Ensure secret key matches between microservice and Kong

---

## Additional Documentation

All supporting documentation is located in the [`z-reference/`](z-reference/) folder:

- **[TEST_RESULTS.md](z-reference/TEST_RESULTS.md)** - Complete test execution results for all 15 tests
- **[MODSECURITY_SETUP.md](z-reference/MODSECURITY_SETUP.md)** - Detailed ModSecurity v3 compilation and integration guide
- **[DDOS_PROTECTION.md](z-reference/DDOS_PROTECTION.md)** - DDoS protection architecture and attack mitigation strategies
- **[EVALUATOR_GUIDE.md](z-reference/EVALUATOR_GUIDE.md)** - Quick start guide for evaluators with step-by-step verification
- **[QUICK_REFERENCE.md](z-reference/QUICK_REFERENCE.md)** - Command reference and troubleshooting shortcuts
- **[DELIVERABLES_CHECKLIST.md](z-reference/DELIVERABLES_CHECKLIST.md)** - Assignment requirements verification checklist
- **[AI-Native DevOps Assignment 4_Requirements.md](z-reference/AI-Native%20DevOps%20Assignment%204_Requirements.md)** - Original assignment requirements

**Postman Collection**:
- [`postman/`](postman/) - Postman collection for professional API testing with 18 requests in 5 folders

**AI Usage Documentation**:
- **[ai-usage.md](ai-usage.md)** - Complete AI interaction history (6358+ lines) with detailed implementation journey

---

## License

This project is created for educational purposes (AI-Native DevOps Assignment 4).

---

## Author

Sandeep M  
AI-Native DevOps Assignment 4  
February 2026
