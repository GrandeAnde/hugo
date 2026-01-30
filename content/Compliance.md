---
title: "Compliance Matrix (NIST 800-171)"
layout: "single"
url: "/compliance/"
summary: "Automated controls mapping and evidence dashboard."
hidemeta: true
disableShare: true
---

## Continuous Compliance Dashboard

This environment utilizes **GitOps** to ensure integrity. Evidence is derived directly from the Source of Truth (the code) and validated via third-party scanners.

### System & Communications Protection (SC)

| ID | Control Requirement | Implementation Strategy | **Live Evidence (Proof)** |
| :--- | :--- | :--- | :--- |
| **3.13.8** | **Cryptographic Protection** | Traffic is encrypted via TLS 1.2+ at the Edge (Cloudflare). Origin server is inaccessible via HTTP. | [🔎 **Live SSL Report**](https://www.ssllabs.com/ssltest/analyze.html?d=andygallegos.com) <br> *(Click to run a real-time third-party scan)* |
| **3.13.1** | **Boundary Protection** | The web application is hosted on Azure PaaS. Direct IP access is obfuscated via Cloudflare Proxy. | [📄 **DNS Configuration**](https://securitytrails.com/domain/andygallegos.com/dns) <br> *(Validates Cloudflare nameservers)* |

### Configuration Management (CM)

| ID | Control Requirement | Implementation Strategy | **Live Evidence (Proof)** |
| :--- | :--- | :--- | :--- |
| **3.4.1** | **Baseline Configuration** | Infrastructure is defined as Code (IaC). No manual console changes are permitted. | [📄 **View Source Config**](https://github.com/GrandeAnde/hugo/blob/main/hugo.yaml) <br> *(Links to the immutable config file)* |
| **3.4.2** | **Enforcement** | The CI/CD pipeline acts as the Gatekeeper. Invalid configurations fail the build before deployment. | [✅ **Build History**](https://https://github.com/GrandeAnde/hugo/actions) <br> *(Proof of successful automated builds)* |

### Identification & Authentication (IA)

| ID | Control Requirement | Implementation Strategy | **Live Evidence (Proof)** |
| :--- | :--- | :--- | :--- |
| **3.5.1** | **Identification** | Administrative access requires MFA-protected GitHub Identity. No shared accounts. | [🔒 **Deployment Policy**](https://github.com/GrandeAnde/blob/main/.github/workflows/azure-static-web-apps.yml) <br> *(Shows secure token injection)* |

