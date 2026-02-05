# Postman Setup Guide

## 📦 Import Collection & Environment

### Step 1: Import Collection
1. Open Postman
2. Click **Import** button (top-left)
3. Select **File** tab
4. Choose: `postman/Kong_API_Platform_Demo.postman_collection.json`
5. Click **Import**

### Step 2: Import Environment
1. Click **Environments** (left sidebar)
2. Click **Import** button
3. Choose: `postman/Kong_Environment.postman_environment.json`
4. Click **Import**
5. **Activate** the environment (select "Kong Environment" from dropdown in top-right)

---

## 📋 Collection Structure

### 1. Public Endpoints (No Auth)
- ✅ **Health Check** - GET /health
- ✅ **Verify Token Endpoint** - GET /verify

### 2. Authentication
- 🔐 **Login (Get JWT Token)** - POST /login
  - Body: username=admin, password=password123
  - Auto-saves token to `{{jwt_token}}` variable

### 3. Protected Endpoints (JWT Required)
- 🔒 **Get Users (Without Token)** - Should return 401
- ✅ **Get Users (With Token)** - Should return 200
- ✅ **Secure Endpoint** - Another protected endpoint

### 4. Rate Limiting Test
- ⚡ **Rate Limit Test** - Click Send 12 times
  - First 10: 200 OK
  - Last 2: 429 Too Many Requests

### 5. DDoS Protection - Attack Tests
- 🛡️ **XSS Attack** - Should return 403 (blocked)
- 🛡️ **SQL Injection** - Should return 403 (blocked)
- 🛡️ **Path Traversal** - Should return 403 (blocked)
- 🛡️ **Command Injection** - Should return 403 (blocked)
- ✅ **Legitimate Request** - Should return 200 (allowed)

---

## 🎥 Video Recording Tips with Postman

### Before Recording
1. ✅ **Arrange Postman window** - Full screen or large enough to read
2. ✅ **Expand response panel** - Make sure status code and body are visible
3. ✅ **Set theme** - Use light theme for better visibility (File → Settings → Themes → Light)
4. ✅ **Close unnecessary tabs** - Keep only the collection you're demoing
5. ✅ **Test all requests** - Make sure everything works before recording

### During Recording
1. **Show collection structure first** - Expand folders to show organization
2. **Click request name** - Clearly before clicking Send
3. **Point to responses** - Use cursor to highlight status codes, headers, body
4. **Show auto-save magic** - After login, show that token is saved to environment
5. **Highlight headers** - Show Authorization header in protected requests
6. **Demonstrate rate limiting visually** - Click Send multiple times, show counter

### Visual Flow for Video
```
1. Show Collection → Expand folders (5 folders total)
2. Click "Health Check" → Send → Point to 200 status
3. Click "Login" → Send → Point to access_token → Show Tests tab (token saved)
4. Click "Get Users (Without Token)" → Send → Point to 401 Unauthorized
5. Click "Get Users (With Token)" → Send → Point to Authorization header → Point to 200 status
6. Click "Rate Limit Test" → Send 12 times → Point to 200s → Point to 429s
7. Click "XSS Attack" → Send → Point to 403 Forbidden
8. Click "SQL Injection" → Send → Point to 403
9. Click "Path Traversal" → Send → Point to 403
10. Click "Command Injection" → Send → Point to 403
11. Click "Legitimate Request" → Send → Point to 200 (WAF allows normal traffic)
```

---

## 🎨 Making Postman Look Good in Video

### Postman Settings for Recording
1. **Font Size**: Settings → General → Font size: 14px (readable on video)
2. **Theme**: Light (better contrast for screen recording)
3. **Layout**: Two-pane (request on left, response on right)
4. **Response Format**: Pretty + JSON (automatically formats JSON)
5. **Console**: Hide console during demo (View → Hide Postman Console)

### What to Show in Each Request
- ✅ **Request URL** (clearly visible)
- ✅ **Method** (GET, POST)
- ✅ **Headers** (especially Authorization)
- ✅ **Body** (for POST requests)
- ✅ **Response Status** (200, 401, 403, 429)
- ✅ **Response Body** (formatted JSON)
- ✅ **Response Time** (shows performance)

---

## 📊 Expected Results Reference

| Request | Status | Response | Notes |
|---------|--------|----------|-------|
| Health Check | 200 | `{"status":"healthy"}` | Public endpoint |
| Verify | 200 | `{"valid":false,"detail":"Token missing"}` | Public endpoint |
| Login | 200 | `{"access_token":"eyJ...","token_type":"bearer"}` | Token auto-saved |
| Users (No Token) | 401 | `{"message":"Unauthorized"}` | JWT required |
| Users (With Token) | 200 | `[{"id":1,"username":"admin",...}]` | Auth success |
| Rate Limit (1-10) | 200 | User data | Within limit |
| Rate Limit (11-12) | 429 | `{"message":"API rate limit exceeded"}` | Limit exceeded |
| XSS Attack | 403 | `<html><title>403 Forbidden</title>...` | WAF blocked |
| SQL Injection | 403 | `<html><title>403 Forbidden</title>...` | WAF blocked |
| Path Traversal | 403 | `<html><title>403 Forbidden</title>...` | WAF blocked |
| Command Injection | 403 | `<html><title>403 Forbidden</title>...` | WAF blocked |
| Legitimate After | 200 | `{"status":"healthy"}` | WAF allows normal |

---

## 🎬 Video Script Using Postman

### Scene 1: Introduction (30s)
> "I'll demonstrate this system using Postman. I've organized 18 requests into 5 folders covering authentication, rate limiting, and DDoS protection."

### Scene 2: Public Endpoints (30s)
1. Click "Health Check" → Send
   > "First, public endpoints. Health check returns 200 OK, no authentication needed."

### Scene 3: Authentication (1m)
1. Click "Get Users (Without Token)" → Send
   > "Without a JWT token, protected endpoints return 401 Unauthorized."
2. Click "Login" → Send
   > "Let me login. See the access token? Postman automatically saved it to our environment variable."
3. Click "Get Users (With Token)" → Send
   > "Now with the token in the Authorization header, we get 200 OK with user data."

### Scene 4: Rate Limiting (45s)
1. Click "Rate Limit Test" → Send 12 times
   > "Kong limits 10 requests per minute. Watch as I click Send rapidly. Requests 1-10 succeed... 11 and 12 return 429 Too Many Requests."

### Scene 5: DDoS Protection (1.5m)
1. Click each attack request
   > "ModSecurity blocks XSS... SQL injection... path traversal... and command injection. All return 403 Forbidden."
2. Click "Legitimate Request"
   > "But normal requests still work fine - 200 OK."

---

## 🚀 Quick Start

**Ready to record? Run this checklist:**

- [ ] Import collection and environment
- [ ] Activate "Kong Environment"
- [ ] Set Postman to Light theme, font size 14px
- [ ] Verify all requests work
- [ ] Clear all response panels
- [ ] Position Postman window for recording
- [ ] Start recording
- [ ] Follow the video script above

---

## 📤 Submission

Include these Postman files in your repository:
```
postman/
├── Kong_API_Platform_Demo.postman_collection.json
├── Kong_Environment.postman_environment.json
└── POSTMAN_SETUP.md (this file)
```

Evaluators can import and test your API immediately!

---

## 🎯 Benefits of Using Postman in Video

✅ **Professional** - Clean UI, organized requests
✅ **Visual** - Easy to see request/response flow
✅ **Reproducible** - Evaluators can import and test themselves
✅ **Clear** - Status codes and responses are obvious
✅ **Interactive** - Shows real-time testing, not just curl output

**Your video will look polished and professional! 🌟**
