---
title: "Zero Trust Automation: A Different Ball Game"
date: 2026-02-17T08:00:00-05:00
draft: false
tags: ["Azure", "Cybersecurity", "PowerShell", "Automation", "Zero Trust", "Compliance", "Microsoft Graph"]
summary: "A journey from on-prem scripting to cloud-native orchestration, exploring why identity-based access and immutable auditing are the true hallmarks of a Senior Cloud Engineer."
---

## The Shift from Scripting to Orchestration

For years, my automation was about *code*.  I would create aservice account, I wrote a a script, and I made a scheduled task. But as I recently discovered while building a serverless user-lifecycle engine in Azure, cloud automation is an entirely different ball game. Scripting and code are the baseline. The real challenege comes from the **orchestration of secure handshakes and RBAC.*

In this project, I built a system that fetches new hire data from an HR API, provisions users in Microsoft Entra ID, and archives a tamper-proof audit log—all without a single hardcoded password or access key.  



---

### Lessons from the Trenches: Cloud vs. On-Prem

My biggest takeaway from this build is that "permissions" in the cloud are far more surgical than traditional file-share permissions.

1. **Identity is the Perimeter:** On-prem, we often rely on broad service accounts. In the cloud, I had to implement **Managed Identities**. This forced me to respect the distinction between the **Control Plane** (reading resource metadata) and the **Data Plane** (writing the actual bits and bytes).
2. **The 'Assembly Hell' Pivot:** I initially hit roadblocks with the standard Microsoft Graph SDKs in the serverless runtime. Instead of being stuck, I pivoted to **Direct REST API calls** using OAuth 2.0 tokens. This made the automation more portable and resilient to module versioning issues.  
3. **The cloud is blank canvass:** After a while of writing scripts on-premise, you get pretty comfortable with your environment.  You have it set up just the way you like with all dependencies, modules, and cmdlets ready to go.  No so in serverless scripting.  You need to know exactly what you need, its compatability, and version.  
4 **The 'Success' of a Failed Deletion:** The most satisfying part of this project wasn't the "Provisioning Successful" message. It was the `Access Denied` I received when I tried to delete the audit log. In a Zero Trust world, the **Policy (WORM)** is more powerful than the **Admin.**

---

### The Architecture: Compliance-as-Code

| Feature | Implementation | Senior-Level "Why" |
| :--- | :--- | :--- |
| **Authentication** | Azure Managed Identity | Eliminates credential leakage risk; follows Zero Trust. |
| **Secrets** | Azure Key Vault | Externalizes 3rd-party API keys from the code. |
| **Provisioning** | Microsoft Graph REST API | Promotes dependency-free execution in serverless runtimes. |
| **Auditing** | Immutable Blob Storage (WORM) | Satisfies SOX 404 controls by preventing log tampering. |

---

### The Final Solution

This PowerShell 7.2 script serves as the engine. I as I wrote this, I began to fully appreciate **Zero Trust.**.  Every connection must be explicitly verified and every action must be immutably recorded.  Every actor needs the right permissions to every resource. 

```powershell
# 1. Authenticate & Fetch Graph Access Token (Identity-First)
try {
    Connect-AzAccount -Identity
    $TokenRequest = Get-AzAccessToken -ResourceUrl "[https://graph.microsoft.com](https://graph.microsoft.com)"
    $GraphToken = $TokenRequest.Token
    Write-Output "Successfully authenticated and retrieved Graph token."
}
catch {
    Write-Error "Authentication Failed: $_"
    return
}

# 2. Securely Fetch HR API Key from Key Vault
$VaultName = "poshportfoliovault"
$SecretName = "mockaroo"
$MockKey = (Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -AsPlainText)

# 3. Simulate HR Trigger (Fetching New Hire Data)
$ApiUrl = "[https://my.api.mockaroo.com/onboarding.json](https://my.api.mockaroo.com/onboarding.json)"
$Headers = @{ "X-API-Key" = $MockKey }
$NewHire = Invoke-RestMethod -Uri $ApiUrl -Method Get -Headers $Headers

# 4. Provisioning & Compliance Logic
try {
    $TargetHire = $NewHire[0] # Selecting the primary record
    if ($null -eq $TargetHire.firstName) { throw "API returned empty data." }
   
    Write-Output "Processing New Hire: $($TargetHire.firstName) $($TargetHire.lastName)"
    $UPN = "$($TargetHire.firstName).$($TargetHire.lastName)@andyagsec482.onmicrosoft.com"
    
    # Constructing the JSON Payload for the Direct REST Call
    $UserBodyObj = @{
        accountEnabled    = $true
        displayName       = "$($TargetHire.firstName) $($TargetHire.lastName)"
        mailNickname      = "$($TargetHire.firstName)$($TargetHire.lastName)"
        userPrincipalName = $UPN
        usageLocation     = "US"
        jobTitle          = "$($TargetHire.jobTitle)"
        passwordProfile   = @{
            forceChangePasswordNextSignIn = $true
            password                      = "InitialPassword123!"
        }
    } 
    $UserBody = $UserBodyObj | ConvertTo-Json -Depth 10
    $AuthHeader = @{ "Authorization" = "Bearer $GraphToken"; "Content-Type" = "application/json" }

    # Provision User in Entra ID
    $GraphUserUri = "[https://graph.microsoft.com/v1.0/users](https://graph.microsoft.com/v1.0/users)"
    $NewUser = Invoke-RestMethod -Uri $GraphUserUri -Method Post -Body $UserBody -Headers $AuthHeader
    Write-Output "Successfully created user with ID: $($NewUser.id)"

    # 5. Archive to Immutable Compliance Vault (WORM)
    $StorageAccountName = "userlifecyclelog"     
    $ContainerName      = "compliance-records"

    $LogEntry = [PSCustomObject]@{
        Timestamp    = (Get-Date).ToUniversalTime()
        Event        = "USER_CREATED"
        UserPrincipal= $UPN
        ComplianceID = "SOX-404-CONTROL"
        Status       = "Success"
    }

    $LocalPath = "$HOME/audit-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $LogEntry | ConvertTo-Json | Out-File -FilePath $LocalPath

    # Creating a Storage Context using OAuth Identity (Zero Secrets)
    $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

    # Upload to WORM Container
    Set-AzStorageBlobContent -File $LocalPath -Container $ContainerName -Blob "Audit-$($NewUser.id).json" -Context $StorageContext
    Write-Output "Compliance log successfully archived to Immutable Vault."
}
catch {
    Write-Error "Provisioning failed: $_"
}

[![View the full script GitHub](https://img.shields.io/badge/View_Full_Script-GitHub-black?logo=github&style=for-the-badge)](https://github.com/GrandeAnde/Portfolio/blob/main/Azure/User_Life_Cycle/User_Onboarding_Script.ps1)