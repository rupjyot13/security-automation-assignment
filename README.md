# Security Automation Assignment — VulnTracker

## 1. Overview

This repository contains a security-focused extension and hardening of the **VulnTracker** application.

The assignment covers:

* Extending the application with secure shared report links
* Identifying and remediating application security vulnerabilities
* Hardening the Docker/container configuration
* Hardening the Kubernetes/Helm deployment
* Reviewing software dependencies and container vulnerabilities
* Documenting findings, remediation decisions, residual risks, and security controls

The application is a Python **FastAPI** service with a SQLite database for local development.

---

## 2. Repository Structure

```text
.
├── app/                         # FastAPI application
│   ├── auth.py                 # Authentication and password handling
│   ├── config.py               # Application configuration
│   ├── database.py             # Database operations
│   ├── main.py                 # API endpoints and application flow
│   └── models.py               # Database models
│
├── tests/                      # Python application tests
│   └── test_api.py
│
├── notify/                     # Node.js notification service
│   ├── src/
│   └── tests/
│
├── helm/vulntracker/           # Kubernetes/Helm deployment
│   ├── templates/
│   ├── Chart.yaml
│   └── values.yaml
│
├── reports/                    # Security scan evidence
│   ├── container.scout.json
│   ├── iac.checkov.json
│   ├── iac-rendered/
│   ├── sast.bandit.json
│   ├── sca.node.npm-audit.json
│   └── sca.pip-audit.json
│
├── docs/
│   ├── findings.md             # Security findings and status
│   ├── remediation-plan.md    # Remediation and residual-risk plan
│   └── executive-summary.md   # Assignment executive summary
│
├── Dockerfile
├── requirements.txt
└── .github/workflows/ci.yml
```

---

# 3. Application Setup

## Prerequisites

For local application development:

* Python 3.11
* pip
* Git

For container testing:

* Docker

For Kubernetes/Helm validation:

* Kubernetes cluster
* Helm
* Appropriate cluster access

---

## 4. Run the Application Locally

Create and activate a Python virtual environment.

### Windows PowerShell

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Install dependencies:

```powershell
pip install -r requirements.txt
```

Start the application:

```powershell
uvicorn app.main:app --reload
```

The application will be available at:

```text
http://localhost:8000
```

Health endpoint:

```text
http://localhost:8000/health
```

Expected response:

```json
{"status":"ok"}
```

FastAPI API documentation is available at:

```text
http://localhost:8000/docs
```

---

# 5. Run Tests

Run the Python test suite:

```powershell
python -m pytest -q
```

The test suite covers the main application flows including:

* Health check
* User registration
* Duplicate-user handling
* Authentication
* Invalid-password handling
* Scan creation
* Scan listing
* Scan search
* Scan status update
* Scan deletion

The repository also contains tests for the Node.js notification service.

From the `notify` directory:

```powershell
npm install
npm test
```

---

# 6. Docker Build and Run

The application can be built and run locally using Docker.

## 6.1 Build the Docker image

From the repository root:

```bash
docker build -t vulntracker-app:task4 .
```

## 6.2 Run the container

The application uses SQLite by default, so no external database configuration is required for a normal local Docker run.

```bash
docker run --rm -p 8000:8000 vulntracker-app:task4
```

The application will be available at:

```text
http://localhost:8000
```

## 6.3 Health check

Verify that the application is running:

```text
http://localhost:8000/health
```

Expected:

```json
{"status":"ok"}
```

### Optional stable JWT secret for local development

The application can generate a random secret when `SECRET_KEY` is not supplied.

For local testing where tokens should remain valid across container restarts, a development-only secret can be supplied:

```bash
docker run --rm -p 8000:8000 -e SECRET_KEY="local-development-secret" vulntracker-app:task4
```

Do **not** commit real production secrets to the repository.

Production deployments should obtain secrets from an external secret-management mechanism.

---

# 7. Docker Security Hardening

The Dockerfile includes several container security controls:

* Python slim base image
* Python bytecode generation disabled
* pip cache disabled
* Dedicated non-root application user
* Application files owned by the application user
* Container runs as a non-root user
* Health check configured
* Application listens on the required application port

The resulting image can be reviewed with Docker Scout:

```bash
docker scout cves vulntracker-app:task4
```

Container scan results are retained under:

```text
reports/container.scout.json
```

Outstanding dependency and container findings are documented rather than being represented as fully remediated.

See:

```text
docs/findings.md
docs/remediation-plan.md
```

---

# 8. Security Remediations

The application was reviewed for application-level security vulnerabilities.

The following findings were remediated.

## SQL Injection

Database queries were changed to use parameterized SQL rather than incorporating user-controlled input directly into SQL statements.

This applies particularly to scan-search functionality.

---

## Broken Object-Level Authorization / IDOR

Access to scans is restricted to the authenticated owner.

The ownership check is applied to direct scan access and search functionality.

This prevents one authenticated user from accessing another user's scan records simply by changing an identifier or search request.

---

## Passwords in Application Logs

Password values are no longer written to application logs.

Sensitive authentication information should not be included in application logging.

---

## JWT `none` Algorithm

JWT validation was restricted so that the application does not accept an unsigned JWT using the `none` algorithm.

The application uses the expected signed JWT algorithm.

---

## Hardcoded JWT Secret

The JWT signing secret is no longer hardcoded in the application source.

The application obtains the secret from configuration/environment where available, with a generated local-development fallback.

Production deployments should provide the secret through external secret management.

---

## Hardcoded Database Password

The database password is no longer stored as a hardcoded application value.

The Kubernetes deployment obtains the database credential through the configured external secret-management flow.

---

# 9. Task 1 — Secure Shared Report Links

The application was extended to support sharing a scan/report through a link.

The implementation includes security controls such as:

* Cryptographically secure random share tokens
* Token hashing before database storage
* Token expiration
* Optional password protection
* Password hashing
* Authenticated ownership requirement when creating a share link
* Generic handling for invalid or expired links
* No raw share token stored in the database

The intended flow is:

```text
Authenticated User
       |
       v
Create Share Link
       |
       v
Secure Random Token
       |
       +----> SHA-256 hash stored in database
       |
       v
Share URL
       |
       v
Recipient accesses report
       |
       +----> Token validated
       +----> Expiration checked
       +----> Optional password checked
       |
       v
Report returned
```

Detailed security findings and residual risks are documented in:

```text
docs/findings.md
docs/remediation-plan.md
```

---

# 10. Kubernetes / Helm Deployment

The application includes a Helm chart under:

```text
helm/vulntracker/
```

The deployment contains multiple Kubernetes security hardening controls.

## Container security context

The workload is configured to:

* Run as a non-root user
* Use an explicit UID/GID
* Disable privilege escalation
* Use a read-only root filesystem
* Drop Linux capabilities
* Use the `RuntimeDefault` seccomp profile

## Service account token

Automatic mounting of the Kubernetes service-account token is disabled where it is not required.

## Image pinning

The deployment supports image digest pinning to reduce the risk of unintentionally deploying a different image behind the same tag.

## Network exposure

The service uses a Kubernetes `ClusterIP` service.

The configured ingress uses an internal AWS Application Load Balancer and restricts inbound CIDRs according to the Helm values.

## NetworkPolicy

A Kubernetes NetworkPolicy is included to restrict pod traffic.

The policy permits only the network traffic required by the current deployment configuration.

## Resource controls

CPU and memory requests/limits are defined in the Helm values.

These controls help provide predictable resource allocation and reduce the risk of unrestricted resource consumption.

---

# 11. Secret Management

The Kubernetes deployment uses an External Secrets configuration to obtain application secrets from an external secret store.

The flow is:

```text
AWS Secrets Manager
        |
        v
External Secrets Operator
        |
        v
Kubernetes Secret
        |
        v
VulnTracker Pod
```

The application receives the required values through Kubernetes secret references.

Production credentials should not be committed to Git.

---

# 12. Infrastructure Security Scanning

The rendered Kubernetes/IaC configuration was reviewed using Checkov.

The scan results are retained under:

```text
reports/iac.checkov.json
reports/iac-rendered/
```

The review identified Kubernetes security controls that were implemented as part of the hardening work.

One remaining Checkov finding concerns secrets being supplied to the application through environment variables.

This is documented as a residual/hardening consideration because the current deployment already uses:

```text
AWS Secrets Manager
        ->
External Secrets Operator
        ->
Kubernetes Secret
```

Further hardening could move sensitive values away from environment variables if required by the target platform/security standard.

---

# 13. Software Composition Analysis

Application dependencies were reviewed using software composition analysis.

Python dependency evidence:

```text
reports/sca.pip-audit.json
```

Node.js dependency evidence:

```text
reports/sca.node.npm-audit.json
```

Some dependency findings remain outstanding.

They are documented as follow-up items rather than being incorrectly marked as remediated.

Recommended follow-up actions include:

1. Review each vulnerable dependency.
2. Identify a compatible fixed version.
3. Test application compatibility.
4. Upgrade the dependency.
5. Re-run SCA.
6. Verify that the vulnerability is resolved.

---

# 14. Static Application Security Testing

Bandit results for the Python application are retained under:

```text
reports/sast.bandit.json
```

SAST findings should be reviewed together with the application code and not treated as automatically exploitable vulnerabilities without validation.

---

# 15. Container Vulnerability Assessment

The built application image was scanned using Docker Scout.

The resulting evidence is stored in:

```text
reports/container.scout.json
```

The scan identified vulnerabilities in the container's operating-system/package dependency layer.

These findings are documented as follow-up work.

A container vulnerability count should not automatically be interpreted as the same number of directly exploitable application vulnerabilities. Individual findings should be reviewed for:

* Severity
* Affected package
* Exploitability
* Application exposure
* Fixed version availability
* Whether the package is actually used at runtime

---

# 16. Residual Security Findings

Not every identified finding was remediated within the current assignment scope.

Examples include:

### Global exception information disclosure

The current exception handling can expose internal error information.

Recommended production hardening:

```text
Client -> Generic error response
Server -> Detailed internal logging
```

Sensitive traceback and implementation details should not be returned to clients.

### Overly permissive CORS

The current configuration allows broad origin handling.

Recommended production hardening is to use an explicit environment-specific origin allowlist.

### Notification service credential

The notification service contains a credential-like configuration value that should be moved to environment/secret management if it is required.

Its current usage and enforcement should also be reviewed.

### Dependency vulnerabilities

Outstanding SCA findings require dependency review and upgrades.

### Container vulnerabilities

Outstanding image vulnerabilities require base-image/package updates and subsequent rescanning.

The complete status of these findings is maintained in:

```text
docs/findings.md
```

---

# 17. CI/CD

The repository contains a GitHub Actions workflow under:

```text
.github/workflows/ci.yml
```

The current workflow validates the application through automated Python and Node.js tests.

Security scan results generated during the assignment are retained under:

```text
reports/
```

Security scanning should be treated as part of the broader DevSecOps lifecycle:

```text
Code Commit
     |
     v
Build
     |
     v
Unit / Integration Tests
     |
     v
SAST
     |
     v
SCA
     |
     v
IaC Scan
     |
     v
Container Build
     |
     v
Container Scan
     |
     v
Security Review / Quality Gates
     |
     v
Deployment
```

The repository documentation distinguishes between scans/evidence produced for the assignment and the currently implemented CI workflow.

---

# 18. Security Documentation

The assignment documentation is available under:

```text
docs/
```

### `docs/findings.md`

Contains:

* Security findings
* Severity
* Affected area
* Remediation status
* Security controls
* Residual risks

### `docs/remediation-plan.md`

Contains:

* Remediated findings
* Findings not remediated
* Residual risk
* Recommended remediation
* Compensating controls
* Follow-up actions

### `docs/executive-summary.md`

Provides the high-level security assessment and summarizes:

* Assignment scope
* Major remediations
* Security testing
* IaC hardening
* Container/dependency findings
* Remaining risks
* Recommended next steps

---

# 19. Validation Commands

Before submitting changes, the following local validation can be performed.

### Python tests

```powershell
python -m pytest -q
```

### Python compilation check

```powershell
python -m py_compile app\database.py app\main.py
```

### Docker build

```bash
docker build -t vulntracker-app:task4 .
```

### Docker vulnerability scan

```bash
docker scout cves vulntracker-app:task4
```

### Node.js tests

```powershell
cd notify
npm install
npm test
cd ..
```

---

# 20. Assignment Scope and Limitations

This repository focuses on the security requirements and hardening work covered by the assignment.

Not every possible security improvement has been implemented.

Where a finding was not remediated, it is explicitly documented with:

* Residual risk
* Recommended remediation
* Required effort
* Existing compensating controls where applicable

This avoids treating unresolved findings as fixed and provides a clear path for future security work.

---

# 21. Final Security Assessment

The assignment implementation improves the security posture of the VulnTracker application through:

* Parameterized database queries
* Object-level authorization checks
* Secure password handling
* JWT algorithm restrictions
* Removal of hardcoded application/database secrets
* Secure shared-report tokens
* Token expiration
* Optional shared-link password protection
* Non-root container execution
* Read-only container filesystem
* Dropped Linux capabilities
* Seccomp hardening
* Kubernetes NetworkPolicy
* Internal load-balancer exposure
* Resource requests and limits
* Image digest pinning
* External secret management
* SAST, SCA, IaC and container security assessment

Remaining risks and follow-up work are intentionally documented rather than hidden.

For the detailed security assessment, see:

```text
docs/findings.md
docs/remediation-plan.md
docs/executive-summary.md
```
