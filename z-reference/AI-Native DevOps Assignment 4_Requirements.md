AI-Native DevOps Assignment 4 

Secure API Platform using Kong on Kubernetes
Context 
Your organization is building a self-managed internal API platform.
Key requirements:
•	APIs must be protected using JWT-based authentication
•	Certain APIs must bypass authentication
•	Traffic protection must include:
o	IP-based rate limiting
o	DDoS protection (open-source, self-managed)
•	Platform must run on Kubernetes
•	API Gateway must be Kong (OSS / self-managed)
You are expected to build the system from scratch, using AI tools as primary assistants for design, coding, debugging, and refactoring.

Problem Statement
Design and implement a Kubernetes-based API platform that exposes a secure microservice through Kong Gateway.
The platform must:
•	Use JWT authentication
•	Store users in a local SQLite database
•	Enforce IP-based rate limiting and IP whitelisting
•	Bypass authentication for selected APIs
•	Be deployable using Helm charts
•	Include custom Kong Lua logic
•	Be reproducible locally or on any Kubernetes cluster

Microservice API Requirements
Implement a sample user service with the following APIs:
Authentication APIs
Endpoint	Method	Description
/login	POST	Authenticate user and return JWT
/verify	GET	Verify JWT token
User APIs
Endpoint	Method	Authentication
/users	GET	Required (JWT)
Public APIs (Authentication Bypass)
Endpoint	Method	Authentication
/health	GET	Not required
/verify	GET	Not required

Database Requirements
•	Use SQLite (local, file-based database)
•	Store:
o	User records
o	Secure password hashes
•	Database must be auto-initialized at service startup
•	No external or managed databases are allowed

Kubernetes & Deployment Requirements
Mandatory
•	Containerize the microservice
•	Kubernetes resources must include:
o	Deployment
o	Service
•	No imperative kubectl commands
•	All resources must be declarative and version-controlled

Kong API Gateway Requirements
Authentication
•	JWT-based authentication using Kong JWT plugin
•	Selected APIs must bypass authentication:
o	/health
o	/verify
•	JWT secrets must be externalized (not hardcoded)

Rate Limiting
•	IP-based rate limiting via Kong plugin
•	Example policy: 10 requests per minute per IP

IP Whitelisting
•	Allow traffic only from configurable CIDR ranges
•	Block all other inbound traffic at the gateway level

Custom Kong Lua Logic
Implement at least one custom Lua script, such as:
•	Custom request/response header injection
•	Additional token validation logic
•	Structured request logging
Requirements:
•	Lua code must be version-controlled
•	Lua logic must be deployed via Kong configuration

DDoS Protection (Mandatory)
Implement one open-source, self-managed DDoS protection mechanism suitable for Kubernetes.
Examples (candidate selects one):
•	NGINX Ingress + ModSecurity
•	Kong + ModSecurity
•	CrowdSec
•	Envoy-based rate and connection controls
The candidate must:
•	Explain the reason for choosing the solution
•	Describe how it integrates with Kong and Kubernetes
•	Demonstrate basic protection behavior

Infrastructure as Code
Mandatory
•	Helm charts for:
o	Microservice deployment
o	Kong configuration
•	Clean and parameterized values.yaml usage
•	Terraform for:
o	Kubernetes cluster provisioning, or
o	Namespaces / networking / base infrastructure
📁 Expected Repository Structure
.
├── microservice/
│   ├── app/
│   ├── Dockerfile
│   └── sqlite.db
├── helm/
│   ├── user-service/
│   └── kong/
├── kong/
│   ├── plugins/
│   │   └── custom.lua
│   └── kong.yaml
├── k8s/
│   └── deployment.yaml
├── terraform/        # optional
├── README.md
└── ai-usage.md


Deliverables
1. README.md (Mandatory)
Must include:
•	High-level architecture overview
•	API request flow (Client → Kong → Microservice)
•	JWT authentication flow
•	Authentication bypass strategy
•	Testing steps for:
o	Rate limiting
o	IP whitelisting
o	DDoS protection

2. AI Usage Documentation (ai-usage.md) - “Please make sure not use AI to generate this file, it should be as it is.” 
Must clearly describe:
•	AI tools used
•	Prompts interaction and history
3. A Short Demo video (~ 5 Mins)