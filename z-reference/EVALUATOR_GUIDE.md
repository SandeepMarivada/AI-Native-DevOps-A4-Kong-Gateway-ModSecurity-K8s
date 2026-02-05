# Evaluator Quick Start Guide

## Prerequisites Verification

Before starting, ensure you have:

```bash
# Check Docker
docker --version
# Expected: Docker version 24.0+ or higher

# Check Minikube
minikube version
# Expected: minikube version: v1.30+ or higher

# Check kubectl
kubectl version --client
# Expected: Client Version: v1.28+ or higher

# Check Helm
helm version
# Expected: version.BuildInfo{Version:"v3.12+"}
```

---

## Complete Deployment Steps (15-20 minutes)

### Step 1: Start Minikube (2 minutes)
```bash
minikube start --driver=docker --cpus=4 --memory=8192
```

**Expected Output**:
```
✨  Using the docker driver based on existing profile
👍  Starting control plane node minikube in cluster minikube
🚜  Pulling base image ...
🔄  Restarting existing docker container for "minikube" ...
🐳  Preparing Kubernetes v1.28.3 on Docker 24.0.7 ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster
```

---

### Step 2: Enable Minikube Tunnel (Keep Running)
**Open a NEW terminal window** and run:
```bash
minikube tunnel
```

**Expected Output**:
```
✅  Tunnel successfully started
📌  NOTE: Please do not close this terminal as this process must stay alive for the tunnel to be accessible ...
```

**⚠️ Important**: Keep this terminal window open for the entire testing session. This exposes the Kong LoadBalancer service at 127.0.0.1.

---

### Step 3: Create Namespace (10 seconds)
```bash
cd "c:\Users\sandeepm\Desktop\AI Assignment\AI-Native DevOps Assignment 4"
kubectl apply -f k8s/namespace.yaml
```

**Expected Output**:
```
namespace/assignment-4 created
```

**Verify**:
```bash
kubectl get namespaces | grep assignment-4
```

---

### Step 4: Build Custom Kong Image with ModSecurity (~12-15 minutes)
```bash
minikube image build -t kong-modsecurity:3.4 ./kong
```

**⏱️ Expected Time**: 10-15 minutes (compiles ModSecurity v3 from source)

**Expected Output** (truncated):
```
[+] Building 865.3s (25/25) FINISHED
 => [internal] load build definition from Dockerfile
 => [internal] load .dockerignore
 => [stage-0 1/18] FROM docker.io/library/kong:3.4.2-ubuntu
 => [stage-0 2/18] RUN apt-get update && apt-get install -y ...
 => [stage-0 3/18] RUN git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity /tmp/modsecurity
 => [stage-0 4/18] WORKDIR /tmp/modsecurity
 => [stage-0 5/18] RUN git submodule init && git submodule update
 => [stage-0 6/18] RUN ./build.sh && ./configure && make && make install
 => [stage-0 7/18] RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /tmp/modsecurity-nginx
 => [stage-0 8/18] RUN wget http://ftp.exim.org/pub/pcre/pcre-8.45.tar.gz -O /tmp/pcre-8.45.tar.gz
 => [stage-0 9/18] WORKDIR /tmp/pcre-8.45
 => [stage-0 10/18] RUN ./configure && make && make install
 => [stage-0 11/18] RUN cd /usr/local/openresty && gmake
 => [stage-0 12/18] RUN find /usr/local/openresty -name "ngx_http_modsecurity_module.so" -exec cp {} /usr/local/lib/ \;
 => [stage-0 13/18] RUN cp /tmp/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
 => [stage-0 14/18] RUN git clone https://github.com/coreruleset/coreruleset /usr/local/owasp-crs
 => [stage-0 15/18] RUN cp /usr/local/owasp-crs/crs-setup.conf.example /usr/local/owasp-crs/crs-setup.conf
 => [stage-0 16/18] RUN mkdir -p /usr/local/kong/nginx-includes && echo "load_module /usr/local/lib/ngx_http_modsecurity_module.so;" > /usr/local/kong/nginx-includes/modsec_load.conf
 => [stage-0 17/18] RUN echo "Include /usr/local/owasp-crs/crs-setup.conf" >> /etc/modsecurity/main.conf
 => [stage-0 18/18] RUN rm -rf /tmp/*
 => exporting to image
 => => exporting layers
 => => writing image sha256:...
 => => naming to kong-modsecurity:3.4
```

**Verify Image Built**:
```bash
minikube image ls | grep kong-modsecurity
```

**Expected**:
```
docker.io/library/kong-modsecurity:3.4
```

---

### Step 5: Build and Deploy Microservice (30 seconds)
```bash
# Build microservice image
minikube image build -t user-service:latest ./microservice

# Deploy microservice
kubectl apply -f k8s/user-service.yaml
```

**Expected Output**:
```
deployment.apps/user-service created
service/user-service created
```

**Verify**:
```bash
kubectl get pods -n assignment-4 -l app=user-service
```

**Expected**:
```
NAME                            READY   STATUS    RESTARTS   AGE
user-service-xxxxxxxxxx-xxxxx   1/1     Running   0          20s
```

---

### Step 6: Deploy Kong Declarative Config (10 seconds)
```bash
kubectl apply -f k8s/configmap.yaml
```

**Expected Output**:
```
configmap/kong-declarative-config created
```

---

### Step 7: Deploy Kong Gateway with Helm (2 minutes)
```bash
helm install kong ./helm/kong-4.40.1.tgz -f k8s/kong-values.yaml -n assignment-4
```

**Expected Output**:
```
NAME: kong
LAST DEPLOYED: ...
NAMESPACE: assignment-4
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
To connect to Kong, please execute the following commands:

export PROXY_IP=$(kubectl get svc --namespace assignment-4 kong-kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Visit http://$PROXY_IP to use Kong Gateway"
```

---

### Step 8: Wait for Pods to be Ready (2-3 minutes)
```bash
# Wait for user service
kubectl wait --for=condition=ready pod -l app=user-service -n assignment-4 --timeout=120s

# Wait for Kong
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n assignment-4 --timeout=180s
```

**Expected Output**:
```
pod/user-service-xxxxxxxxxx-xxxxx condition met
pod/kong-kong-xxxxxxxxxx-xxxxx condition met
```

**Verify All Pods Running**:
```bash
kubectl get pods -n assignment-4
```

**Expected**:
```
NAME                            READY   STATUS    RESTARTS   AGE
kong-kong-xxxxxxxxxx-xxxxx      1/1     Running   0          2m
user-service-xxxxxxxxxx-xxxxx   1/1     Running   0          3m
```

---

### Step 9: Verify Kong Service (10 seconds)
```bash
kubectl get svc kong-kong-proxy -n assignment-4
```

**Expected Output**:
```
NAME              TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
kong-kong-proxy   LoadBalancer   10.96.xxx.xxx   127.0.0.1     80:xxxxx/TCP,443:xxxxx/TCP   2m
```

**⚠️ Critical**: EXTERNAL-IP must be `127.0.0.1` (provided by minikube tunnel)

---

### Step 10: Test Health Endpoint (5 seconds)
```bash
curl http://127.0.0.1/health
```

**Expected Response**:
```json
{"status":"healthy"}
```

**✅ If you see this response, deployment is successful!**

---

## Quick Test Suite (5 minutes)

### Test 1: Login and Get JWT Token
```bash
curl -X POST http://127.0.0.1/login \
  --data-urlencode "username=admin" \
  --data-urlencode "password=password123"
```

**Expected**:
```json
{
  "access_token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsImV4cCI6MTc3MDIxOTI4MCwiaXNzIjoiYXNzaWdubWVudC1pc3N1ZXIifQ...",
  "token_type":"bearer"
}
```

**Save the token**:
```bash
# Bash/WSL
export TOKEN="<paste-access-token-value>"

# PowerShell
$TOKEN="<paste-access-token-value>"
```

---

### Test 2: Access Protected Endpoint WITHOUT JWT (Should Fail)
```bash
curl -v http://127.0.0.1/users
```

**Expected**: `401 Unauthorized`

---

### Test 3: Access Protected Endpoint WITH JWT (Should Succeed)
```bash
curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1/users
```

**Expected**:
```json
[{"id":1,"username":"admin","is_active":true}]
```

---

### Test 4: Rate Limiting (10 requests/minute)
```bash
# Bash/WSL
for i in {1..12}; do
  echo "Request $i:"
  curl -s -o /dev/null -w "  HTTP Status: %{http_code}\n" \
    -H "Authorization: Bearer $TOKEN" \
    http://127.0.0.1/users
done

# PowerShell
foreach ($i in 1..12) {
  Write-Host "Request $i:"
  curl -s -o $null -w "  HTTP Status: %{http_code}`n" `
    -H "Authorization: Bearer $TOKEN" `
    http://127.0.0.1/users
}
```

**Expected**:
```
Request 1:  HTTP Status: 200
Request 2:  HTTP Status: 200
...
Request 10: HTTP Status: 200
Request 11: HTTP Status: 429  ← Rate limit exceeded
Request 12: HTTP Status: 429
```

---

### Test 5: DDoS Protection - XSS Attack
```bash
curl -v "http://127.0.0.1/health?test=<script>alert('xss')</script>"
```

**Expected**: `403 Forbidden` (ModSecurity WAF blocked the attack)

---

### Test 6: DDoS Protection - SQL Injection
```bash
curl -v -G --data-urlencode "id=1' OR '1'='1" http://127.0.0.1/health
```

**Expected**: `403 Forbidden` (ModSecurity WAF blocked the attack)

---

### Test 7: Legitimate Request After Attacks
```bash
curl http://127.0.0.1/health
```

**Expected**: `200 OK` with `{"status":"healthy"}` (legitimate traffic still works)

---

## Verification Checklist

| #  | Requirement | Test Command | Expected Result | Status |
|----|-------------|--------------|-----------------|--------|
| 1  | Kubernetes Platform | `kubectl get nodes` | minikube Ready | ⬜ |
| 2  | Kong OSS Gateway | `kubectl get pods -n assignment-4` | kong-kong Running | ⬜ |
| 3  | Public Endpoints (No Auth) | `curl http://127.0.0.1/health` | 200 OK | ⬜ |
| 4  | JWT Authentication | `curl http://127.0.0.1/users` | 401 Unauthorized | ⬜ |
| 5  | JWT Access Granted | `curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1/users` | 200 + data | ⬜ |
| 6  | Rate Limiting | 12 requests loop | 200×10, 429×2 | ⬜ |
| 7  | DDoS - XSS Block | `curl "http://127.0.0.1/health?test=<script>"` | 403 Forbidden | ⬜ |
| 8  | DDoS - SQLi Block | `curl -G --data-urlencode "id=1' OR '1'='1" http://127.0.0.1/health` | 403 Forbidden | ⬜ |
| 9  | ModSecurity Module | `kubectl exec -n assignment-4 deployment/kong-kong -- ls /usr/local/lib/ngx_http_modsecurity_module.so` | File exists | ⬜ |
| 10 | Legitimate Traffic | `curl http://127.0.0.1/health` | 200 OK | ⬜ |

---

## Troubleshooting Common Issues

### Issue 1: Kong Pod Not Starting (CrashLoopBackOff)
**Symptom**: `kubectl get pods -n assignment-4` shows kong-kong pod with CrashLoopBackOff

**Solution**:
```bash
# Check logs
kubectl logs -n assignment-4 deployment/kong-kong --tail=50

# Common causes:
# 1. Image not found
minikube image ls | grep kong-modsecurity

# 2. ConfigMap not created
kubectl get configmap -n assignment-4

# 3. Rebuild image if corrupted
minikube image rm kong-modsecurity:3.4
minikube image build -t kong-modsecurity:3.4 ./kong
kubectl rollout restart deployment kong-kong -n assignment-4
```

---

### Issue 2: No External-IP for Kong Service
**Symptom**: `kubectl get svc kong-kong-proxy -n assignment-4` shows `<pending>` for EXTERNAL-IP

**Solution**:
```bash
# Ensure minikube tunnel is running
# Open NEW terminal:
minikube tunnel

# Keep this terminal open!
```

---

### Issue 3: curl Returns "Could not resolve host"
**Symptom**: `curl http://127.0.0.1/health` returns connection error

**Solution**:
```bash
# 1. Verify minikube tunnel running
# 2. Check Kong service
kubectl get svc kong-kong-proxy -n assignment-4

# 3. Test with port-forward (alternative)
kubectl port-forward -n assignment-4 svc/kong-kong-proxy 8000:80
# Then use: curl http://localhost:8000/health
```

---

### Issue 4: 401 Unauthorized on Login
**Symptom**: POST /login returns 401

**Solution**:
```bash
# 1. Verify user service is running
kubectl get pods -n assignment-4 -l app=user-service

# 2. Check user service logs
kubectl logs -n assignment-4 -l app=user-service --tail=50

# 3. Verify database initialized
kubectl exec -n assignment-4 deployment/user-service -- python -c "from app.database import init_db; init_db()"

# 4. Restart user service
kubectl rollout restart deployment user-service -n assignment-4
```

---

### Issue 5: ModSecurity Not Blocking Attacks
**Symptom**: XSS/SQLi attacks return 200 OK instead of 403

**Solution**:
```bash
# 1. Verify ModSecurity module loaded
kubectl exec -n assignment-4 deployment/kong-kong -- \
  ls -la /usr/local/lib/ngx_http_modsecurity_module.so

# Expected: -rwxr-xr-x 1 root root 225856 ...

# 2. Check ModSecurity rules loaded
kubectl exec -n assignment-4 deployment/kong-kong -- \
  ls -la /usr/local/owasp-crs/rules/ | wc -l

# Expected: 40+ files

# 3. Verify environment variables
kubectl get deployment kong-kong -n assignment-4 -o yaml | grep -E "nginx_|modsecurity"

# Expected:
# - name: KONG_NGINX_MAIN_INCLUDE
#   value: /usr/local/kong/nginx-includes/modsec_load.conf
# - name: KONG_NGINX_PROXY_MODSECURITY
#   value: "on"
# - name: KONG_NGINX_PROXY_MODSECURITY_RULES_FILE
#   value: /etc/modsecurity/main.conf
```

---

## Complete Documentation Reference

- **[README.md](README.md)** - Complete deployment and testing guide
- **[TEST_RESULTS.md](TEST_RESULTS.md)** - Detailed test execution results (14 tests)
- **[MODSECURITY_SETUP.md](MODSECURITY_SETUP.md)** - ModSecurity v3 implementation deep-dive
- **[DDOS_PROTECTION.md](DDOS_PROTECTION.md)** - DDoS protection architecture and strategies
- **[ai-usage.md](ai-usage.md)** - AI tools usage documentation

---

## Assignment Requirements Mapping

| Requirement | Implementation | Verification |
|-------------|----------------|--------------|
| **Platform: Kubernetes** | Minikube v1.30+ | `kubectl get nodes` |
| **API Gateway: Kong OSS** | Kong 3.4.2 with custom image | `kubectl get pods -n assignment-4` |
| **Microservice: Python** | FastAPI + SQLite | `curl http://127.0.0.1/health` |
| **JWT Authentication** | Kong JWT plugin + FastAPI issuer | `curl -X POST http://127.0.0.1/login` |
| **Authentication Bypass** | Route-level plugin configuration | `curl http://127.0.0.1/health` (no JWT) |
| **Rate Limiting** | Kong rate-limiting plugin (10/min) | 12 requests loop |
| **DDoS Protection** | **ModSecurity v3 + OWASP CRS** | XSS/SQLi attack tests |

---

## Success Criteria

✅ **Deployment Success**: All pods Running (1/1)  
✅ **Public Access**: /health, /verify, /login return 200 without JWT  
✅ **Protected Access**: /users, /secure require JWT (401 without, 200 with)  
✅ **Rate Limiting**: 10 requests pass, 11+ return 429  
✅ **DDoS Protection**: XSS, SQLi, Path Traversal, Command Injection return 403  
✅ **Legitimate Traffic**: Normal requests still work after attacks  

---

## Estimated Evaluation Time

- **Environment Setup**: 5 minutes (minikube start + tunnel)
- **Image Build**: 15 minutes (ModSecurity compilation)
- **Deployment**: 5 minutes (Helm install + wait for pods)
- **Testing**: 10 minutes (10 tests)
- **Total**: **~35 minutes**

---

## Contact Information

For issues or questions during evaluation, refer to:
- Comprehensive test results: [TEST_RESULTS.md](TEST_RESULTS.md)
- Technical deep-dive: [MODSECURITY_SETUP.md](MODSECURITY_SETUP.md)
- Architecture details: [DDOS_PROTECTION.md](DDOS_PROTECTION.md)

**Note**: All commands have been tested and verified on Windows 11 with WSL2, Docker Desktop, and Minikube 1.32.0.
