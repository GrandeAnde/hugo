---
title: "Compliance Does Not Mean Complacent: How I Silenced 83% of Our Alert Noise"
date: 2026-01-29T10:00:00-05:00
draft: false
tags: ["PowerShell", "GRC", "Exchange", "Automation", "Compliance"]
categories: ["Engineering", "Security Operations"]
summary: "How I used PowerShell to audit Exchange logs, identifying that 83% of our alert volume was technical debt masquerading as compliance."
---

In the world of DoD contracting and high-security infrastructure, "Compliance" is mandatory.  Because of this, there will often be little to no discussion about the nuances.  Simply put, meeting compliance is the goal and meeting it is good enough.   We log everything. We alert on everything.  Because a STIG says that we must.  

I had a difficult time adjusting to this, but noise has always been a problem in any IT environment I have been a part of.  Especially in our environment.  "If the STIG says so, then we don't have a say".  And so we dealt with the rules and the noise and the flooded folders and occasional errant alert storms. 

And this worked fine as we focused on growth, because you can fine tune things AFTER you reach your goal, right?  But in the mean time, we were getting complacement and lazy.  THere is simply no other way to put it.  Our team was receiving hundreds of operational alerts daily - snapshots, backup notifications, service hiccups - and the volume was so high that it triggered a collective analsysis paralysis where everyone knew there were a lot of alerts but no one paid attention to them, even as we were getting slammed with them.

But this isn't operational maturity.  It isn't even basic best practice and after my mailbox exploded one day, I decided to take on the task of fixing this.

Ideally, an entire revamp of our monitoring system would be ideal.  Zabbix or Nagios.  Proper ITSM.  But we aren't there yet and even if we got everything we wanted today, we were still engaging in lazy bad practice.  Instead of 20 services sending 100 emails, we'd have 1 server sending 200 emails.  

I decided to stop clearing the inbox and start auditing it. Here is how I used PowerShell to turn noise back into signal.

Huge shoutout the Embrace The Red who helped give me an organizational and operational framework that went beyond technical: https://embracethered.com/blog/posts/2025/the-normalization-of-deviance-in-ai/

## The Problem: The "Compliance" Trap

The issue wasn't just annoyance; it was data integrity. When I looked at our alerts and started asking questions, I realized something.  We were qietly normalizing warning signs while progress marches forward.  In other words, past success and future progress was what we used to shape our risk tolerance.  You know things are setting up for disaster when the blinking lights are ignored.   All it takes is one really meaningful alert to sneak by to bring things down. 

> "We were qietly normalizing warning signs while progress marches forward."
>
> — *https://embracethered.com/blog/posts/2025/the-normalization-of-deviance-in-ai/*


## The Solution: PowerShell as an Auditor

I turned to the raw Exchange Transport Logs. At first I tried looking for the sending domains with the highest count.  But this only showed numbers, not behaviors. 

I wrote a PowerShell script to parse the logs, but I made a crucial architectural decision: I filtered by the `RECEIVE` EventID, not `DELIVER`.

* **DELIVER** tells you how many people got the email (e.g., 10 recipients = 10 logs).
* **RECEIVE** tells you how many times the device physically connected to the server.

This distinction was the key to the entire investigation.

### The Analysis Script

Here is the core logic I used to audit the traffic. It groups traffic by "Sender" and "Subject" to identify the noisiest talkers, while filtering out known-good traffic.

```powershell
$StartDate = (Get-Date).AddHours(-24)
$EndDate   = Get-Date

# Filter for RECEIVE events to spot connection volume, not email volume
Get-ExchangeServer | Get-MessageTrackingLog -ResultSize Unlimited -EventId RECEIVE -Start $StartDate -End $EndDate |
    Where-Object { $_.Sender -like "*@domain1.com" } |
    Group-Object -Property Sender, MessageSubject |
    Sort-Object Count -Descending |
    Select-Object Count, 
                  @{Name="Sender"; Expression={$_.Group[0].Sender}}, 
                  @{Name="Subject"; Expression={$_.Group[0].MessageSubject}} |
    Format-Table -AutoSize
```

## The "Micro-Burst" Discovery

My script uncovered a massive discrepancy. I found a single system generating **10 separate SMTP connections per second** to send the exact same alert to 10 different people.

I quickly realized that we were facing an architectural issue.  They alerts were made to satisfy compliance, not actually alert people. 

Instead of sending one email to a Distribution List, the device was looping through a list of admins and initiating a new TCP handshake for every single one. It was effectively launching a micro-Denial of Service (DoS) attack on our own Exchange Receive Connectors every time it wanted to say "Hello."

## Before & After: The Data

Once we identified the "looping" behaviors and the "Status Update" spam, the metrics were undeniable:

* **Before:** A 24-hour window showed **600+ alerts**. The team assumed the network was unstable and the servers were on fire.
* **The Reality:** My analysis proved these 600 alerts were actually just **60 unique events**, inflated by poor configuration and "Reply All" logic.
* **After:** By fixing the application loops and tuning the alert thresholds (e.g., "Alert only if snapshot > 72 hours"), we reduced volume by **83%**.

## Conclusion

True compliance isn't about having the logs; it's about having the *reaction*.

Alerts were not something meaningful and impactful.  We didn't look at inbox folder ABC and see 1200 unread emails.  We now saw 1 and immediately checked it out.  

I didn't prevent the sky from falling, as much as I'd like to pretend I did.  All I did was clean up some technical debt with one afternoon playing around with Exchange Management Shell.  But it made such a large operational impact that I felt it was worth sharing. 

