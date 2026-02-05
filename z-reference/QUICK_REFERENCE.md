# Quick Reference Card

## Essential Commands (Copy-Paste Ready)

### 🚀 Deployment (One-Time Setup)
```bash
# 1. Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# 2. Open NEW terminal → Run and keep open:
minikube tunnel

# 3. Deploy (in original terminal)
cd "c:\Users\sandeepm\Desktop\AI Assignment\AI-Native DevOps Assignment 4"
kubectl apply -f k8s/namespace.yaml
minikube image build -t kong-modsecurity:3.4 ./kong  # ~15 min
minikube image build -t user-service:latest ./microservice
kubectl apply -f k8s/user-service.yaml
kubectl apply -f k8s/configmap.yaml
helm install kong ./helm/kong-4.40.1.tgz -f k8s/kong-values.yaml -n assignment-4

# 4. Wait for ready
kubectl wait --for=condition=ready pod -l app=user-service -n assignment-4 --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n assignment-4 --timeout=180s
```

---

### ✅ Verification
```bash
kubectl get pods -n assignment-4        # Should show: 2 pods, both 1/1 Running
kubectl get svc kong-kong-proxy -n assignment-4  # EXTERNAL-IP: 127.0.0.1
curl http://127.0.0.1/health            # Should return: {"status":"healthy"}
```

---

### 🔐 Authentication Tests
```bash
# Login (get JWT token)
curl -X POST http://127.0.0.1/login \
  --data-urlencode "username=admin" \
  --data-urlencode "password=password123"

# Save token (replace YOUR_TOKEN with actual value from above)
export TOKEN="YOUR_TOKEN"  # Bash/WSL
$TOKEN="YOUR_TOKEN"        # PowerShell

# Test WITHOUT token (should fail with 401)
curl -v http://127.0.0.1/users

# Test WITH token (should succeed with 200)
curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1/users
```

---

### 📊 Rate Limiting Test (10 req/min limit)
```bash
# Bash/WSL
for i in {1..12}; do curl -s -o /dev/null -w "Request $i: %{http_code}\n" -H "Authorization: Bearer $TOKEN" http://127.0.0.1/users; done

# PowerShell
foreach ($i in 1..12) { curl -s -o $null -w "Request $i: %{http_code}`n" -H "Authorization: Bearer $TOKEN" http://127.0.0.1/users }

# Expected: Requests 1-10 = 200, Requests 11-12 = 429
```

---

### 🛡️ DDoS Protection Tests (ModSecurity WAF)
```bash
# XSS Attack (should return 403)
curl -v "http://127.0.0.1/health?test=<script>alert('xss')</script>"

# SQL Injection (should return 403)
curl -v -G --data-urlencode "id=1' OR '1'='1" http://127.0.0.1/health

# Path Traversal (should return 403)
curl -v "http://127.0.0.1/health?file=../../etc/passwd"

# Command Injection (should return 403)
curl -v "http://127.0.0.1/health?cmd=;cat%20/etc/passwd"

# Legitimate request (should return 200)
curl http://127.0.0.1/health
```

---

## 🎯 Test Results Summary

| Test | Command | Expected |
|------|---------|----------|
| **Health Check** | `curl http://127.0.0.1/health` | `200 {"status":"healthy"}` |
| **Login** | `curl -X POST http://127.0.0.1/login -d "username=admin&password=password123"` | `200 + access_token` |
| **No Auth Fails** | `curl http://127.0.0.1/users` | `401 Unauthorized` |
| **With Auth Works** | `curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1/users` | `200 + user data` |
| **Rate Limit** | 12 requests | `200×10, 429×2` |
| **Block XSS** | `curl "http://127.0.0.1/health?test=<script>"` | `403 Forbidden` |
| **Block SQLi** | `curl -G --data-urlencode "id=1' OR '1'='1" http://127.0.0.1/health` | `403 Forbidden` |

---

## 🔧 Troubleshooting

### Kong Pod CrashLooping?
```bash
kubectl logs -n assignment-4 deployment/kong-kong --tail=50
minikube image ls | grep kong-modsecurity  # Verify image exists
```

### No External-IP?
```bash
# Ensure minikube tunnel is running in separate terminal
minikube tunnel  # Keep this open!
```

### Connection Refused?
```bash
kubectl get svc kong-kong-proxy -n assignment-4  # Check EXTERNAL-IP
kubectl port-forward -n assignment-4 svc/kong-kong-proxy 8000:80  # Alternative
```

### ModSecurity Not Blocking?
```bash
kubectl exec -n assignment-4 deployment/kong-kong -- ls /usr/local/lib/ngx_http_modsecurity_module.so
kubectl exec -n assignment-4 deployment/kong-kong -- cat /etc/modsecurity/modsecurity.conf | grep SecRuleEngine
```

---

## 📚 Documentation Index

| Document | Purpose |
|----------|---------|
| **EVALUATOR_GUIDE.md** | Complete step-by-step deployment guide (35 min) |
| **README.md** | Full project documentation (architecture, deployment, testing) |
| **TEST_RESULTS.md** | Detailed test results for all 14 tests |
| **MODSECURITY_SETUP.md** | ModSecurity v3 implementation technical deep-dive |
| **DDOS_PROTECTION.md** | DDoS protection architecture and attack mitigation |
| **ai-usage.md** | AI tools usage documentation |

---

## ⏱️ Time Estimates

- **Minikube Start**: 2 min
- **Image Build**: 15 min (ModSecurity compilation)
- **Deployment**: 5 min
- **Testing**: 10 min
- **Total**: **~32 minutes**

---

## 🎓 Assignment Requirements Checklist

- ✅ Platform: Kubernetes (Minikube)
- ✅ API Gateway: Kong OSS 3.4.2
- ✅ Microservice: Python FastAPI
- ✅ JWT Authentication: Kong JWT plugin + FastAPI
- ✅ Authentication Bypass: Public routes (/health, /verify, /login)
- ✅ Rate Limiting: 10 requests/minute per IP
- ✅ **DDoS Protection: ModSecurity v3 + OWASP CRS 3.3.4**

---

## 🆘 Need Help?

1. Check logs: `kubectl logs -n assignment-4 deployment/kong-kong --tail=50`
2. Verify pods: `kubectl get pods -n assignment-4`
3. Review: **EVALUATOR_GUIDE.md** (comprehensive troubleshooting)
4. Technical details: **MODSECURITY_SETUP.md**

---

**Last Updated**: February 4, 2026  
**Tested On**: Windows 11, WSL2, Docker Desktop 24.0.7, Minikube 1.32.0
