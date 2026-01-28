---
title: "Building a CMMC-Ready Portfolio: A GitOps Approach"
date: 2026-01-27
draft: false
tags: ["GRC", "Azure", "DevOps", "CMMC"]
summary: "How I architected a low-maintenance, high-security personal site."
---

## 1. Introduction: The Objective

I've been wanting to make a personal blog for some time.  I find them a unique window into the authors personality and they have a level of familiarity that is often lost on linkedin. 

I went back and forth about hosting a public website, because there are so many options.  Coming from a traditional sysadmin backround, I of course went down the LAMP road, but ultimately decided on a cloud first infrastructure for the following reasons:  

* **Risk Context:**
 Hosting a public web presence using traditional on-premise infrastructure or dynamic Content Management Systems (CMS) creates a broad attack surface, requiring continuous patch management.  Ain't nobody got time for that. 

* **Operational Impact:**  
A compromise of this infrastructure would result in significant reputational damage.  Best case scenario, someone defaces my page.  Worst case scenario, someone uses my page as a vector to spread malicious malware.  Either way, it would result in an ndermining my credibility as a security practitioner.

* **Mitigation Strategy:** 
To reduce this risk to an acceptable level, I implemented an Attack Surface Reduction strategy by utilizing Azure PaaS (Static Web Apps) and Hugo Static Site Generator. This architecture eliminates the infrastructure vector entirely and shifts the burden of underlying infrastructure security to the Cloud Provider (thank you, Shared Responsibility Model). Integrity is enforced via GitOps, ensuring that no unauthorized changes can occur outside of the approved CI/CD pipeline. 

## 2. High-Level Architecture (The "System Security Plan")

### Core Components
* **Compute: Azure Static Web Apps**
    * Serverless, PaaS architecture.
    * Easy to create and back up via Infrastructure as Code (Bicep).
* **Edge Security: Cloudflare**
    * Provides DNS management, DDoS Protection, and TLS 1.2+ enforcement.
    * Scalable to additional security services (WAF) if needed.
* **Engine: Hugo**
    * Go-based static generator.
    * Simple, text-based content makes it incredibly easy to deploy via Git.



![Architecture Diagram](/githubci.png)
*Figure 1: High-Level Architecture demonstrating Separation of Duties and Edge Protection.*

---

## 3. Implementation Phase 1: The Secure Baseline

Before writing a single line of content, I needed to establish a trusted development environment. In GRC terms, we cannot ensure the integrity of the output (the website) if we cannot trust the input (the workstation).

### The Trusted Workstation (Access Control)
I developed this site on a machine enforcing **Least Privilege**. Daily development occurs under a standard user account, with User Account Control (UAC) requiring separate administrative credentials for any system-level changes. This mitigates the risk of malicious software being executed if my standard user account were to be compromised.

### Version Control as Audit Trail (Non-Repudiation)
I initialized a Git repository to serve as the single source of truth. Every change to the site, whether infrastructure configuration or blog content, is committed with a timestamp and author attribution. This satisfies the fundamental requirement of **Configuration Management**: knowing exactly who changed what, and when.

### Supply Chain Risk Management (Dependencies)
CMMC Level 2 requires strict **Supply Chain Risk Management (SCRM)**. To satisfy this, I rejected the common practice of "copying and pasting" theme files. Instead, I used Git Submodules to pinpoint an exact, immutable version of the dependency.

~~~bash
# Adding the theme as a submodule to ensure integrity
git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
~~~

**Why this command matters:**
* **Integrity:** It locks the site to a specific commit hash. This prevents "upstream drift" where a theme developer's changes could silently break the site or introduce vulnerabilities.
* **Reproducibility:** The `--depth=1` flag creates a "shallow clone," ensuring I am pulling only the necessary code artifact without the entire history.

---

## 4. Implementation Phase 2: Automated Deployment (CI/CD)

As a sysadmin transitoning into devops workflows, I am focusing on automation.  Humans should not touch production servers. To solve this, I implemented a **Continuous Integration/Continuous Deployment (CI/CD)** pipeline using GitHub Actions and Azure Static Web Apps.

### The Pipeline as Gatekeeper (Change Control)
I configured Azure to act as the build agent. When I push code to the `main` branch, a GitHub Action triggers automatically. It performs a "clean build" of the site in a temporary container.

* **If the build fails:** The pipeline stops. The production site remains untouched.
* **If the build passes:** The artifacts are deployed to the Azure content network.

Invalid configurations are rejected before they ever reach the public.

### Troubleshooting "Dependency Hell" (Configuration Management)
During the initial deployment, the pipeline failed. The build logs indicated a version mismatch: my local environment was using Hugo `0.146.0` (required by the theme), but the default Azure build agent was running `0.124.0`.

In a traditional environment, a sysadmin might manually log into the server to upgrade the software. In a GitOps workflow, this is forbidden. Instead, I enforced the configuration via code. I updated the workflow YAML file to explicitly define the build environment:

~~~yaml
      - name: Build And Deploy
        uses: Azure/static-web-apps-deploy@v1
        with:
           app_build_command: "hugo"
        env:
           HUGO_VERSION: "0.146.0" # Enforcing the specific dependency version
~~~

**The GRC Takeaway:**
By declaring the version in the pipeline configuration, I eliminated "Configuration Drift." The build environment is now **idempotent**.  It will behave exactly the same way today as it will in six months, regardless of what defaults Microsoft changes in the background.

---

## 5. Implementation Phase 3: Edge Protection (DNS & Identity)

For the final layer of the architecture, I focused on **System and Communications Protection (SC)** by utilizing Cloudflare as the DNS provider and edge proxy.

### Availability & DDoS Mitigation
I configured Cloudflare to proxy all traffic before it reaches Azure. This hides the actual "Origin" IP address of the Azure resource.

* **The Sysadmin View:** This solves the technical challenge of "CNAME Flattening," allowing me to point the root domain (`andygallegos.com`) directly to an Azure FQDN, which standard DNS does not support.
* **The GRC View:** This acts as a shield. Cloudflare absorbs Layer 3/4 Distributed Denial of Service (DDoS) attacks at the edge, ensuring **Availability** (one of the three pillars of the CIA Triad) remains high even under stress.

### Data in Transit (Encryption)
To satisfy **NIST 800-171 (SC.L2-3.13.8 - Cryptographic Protection)**, I enforced strict TLS 1.2+ encryption.

* **Client to Edge:** Cloudflare enforces HTTPS for all visitors.
* **Edge to Origin:** I configured "Full (Strict)" encryption, ensuring that traffic between Cloudflare and Azure is also encrypted using a trusted CA certificate. There is no point in the transmission path where data travels in plain text.

### Residual Risk & Mitigation
While Cloudflare protects the primary domain, the direct Azure default URL (`*.azurestaticapps.net`) remains publicly accessible due to the limitations of the Azure Static Web Apps "Free" tier. In a production enterprise environment, I would mitigate this by upgrading to the Standard plan and implementing **IP Restrictions** to whitelist *only* Cloudflare's IP ranges, effectively "locking the origin."

### Domain Validation (Identity)
Before Azure would serve traffic for my domain, I had to prove ownership via a DNS TXT record. This challenge-response mechanism prevents **Subdomain Takeover** attacks, ensuring that only authorized administrators can bind the organization's domain to a cloud resource.

---

## Conclusion: The "Compliance" Audit

What started as a simple portfolio project became a practical exercise in **Secure Systems Engineering**. By shifting from a traditional "manage the server" mindset to a "manage the code" mindset, I achieved:

1.  **Auditable Change Management:** Every modification is version-controlled and attributed.
2.  **Idempotent Deployment:** The infrastructure can be rebuilt instantly with identical results.
3.  **Zero-Touch Production:** Humans do not have write access to the live environment.

This architecture demonstrates that **CMMC compliance** isn't just about writing policy documents—it's about designing systems that are secure by default.

## What's Next: Disaster Recovery and Compliance Checks ##

1. I want to develop a robust and automated disaster recovery set up.  I want this site to be restored within minutes if it were ever to be removed.   My Git repository and a Bicep template will come into play.
2. I want to script and automate compliance checks to make sure some basline security measures are taking place. Eventually, I'd like to scale this up to include live deployment blockers.  If any code is deployed with improper settings, than CI will be blocked until evaluation.