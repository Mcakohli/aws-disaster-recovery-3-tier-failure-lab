# AWS Resilience Engineering: Multi-Tier Failure & Disaster Recovery Architecture

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?logo=amazon-aws&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?logo=ubuntu&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?logo=nginx&logoColor=white)
![Architecture](https://img.shields.io/badge/Resilience-Compute%20%7C%20Storage%20%7C%20Region-blue)

A production-grade implementation of cloud resilience and Disaster Recovery (DR) strategies on AWS. This project simulates and validates recovery mechanisms across three distinct failure domains: **Single-Node Compute Outage**, **Data Volume Corruption/Deletion**, and **Complete Regional Failure** across **Mumbai (`ap-south-1`)** and **Hyderabad (`ap-south-2`)**.

---

## 🎯 Failure Scenarios & Recovery Runbook

| Failure Domain | Simulated Incident | Root Cause | Recovery Strategy | Artifact Used |
| :--- | :--- | :--- | :--- | :--- |
| **Level 1: Compute Crash** | Primary EC2 terminated | OS/Hardware failure | Rapid re-provisioning via pre-baked Golden AMI | Custom AMI (`devopsshack-base-ami`) |
| **Level 2: Data Loss** | `orders.txt` deleted | Accidental human error | Point-in-time state rollback from snapshot | Amazon EBS Snapshot (`gp3`) |
| **Level 3: Regional Outage** | Primary region (`ap-south-1`) down | Regional cloud disaster | Cross-region Pilot Light spin-up in `ap-south-2` | Cross-region copied AMI & Snapshot |

---

## 🏗️ Architectural Pattern

```text
[ Primary Region: Mumbai (ap-south-1) ]
       │
       ├── EC2 Web Server (Nginx) ──── Root OS Volume (/)
       │                                       │ (AMI Capture)
       │                                       ▼
       │                              [ Golden Base AMI ]
       │                                       │
       └── Secondary Block Device (/dev/nvme1n1) ──► Mounted at: /production_data
                 (ext4 filesystem)                     │ (Point-in-Time Snapshot)
                 (symlinked to Nginx web root)         ▼
                                              [ EBS Snapshot ]
                                                       │
                           ════════════════════════════╪════════════════════════════
                                          Cross-Region Replication
                           ════════════════════════════╪════════════════════════════
                                                       ▼
[ DR Region: Hyderabad (ap-south-2) ]
       │
       ├── Restored EC2 (from replicated AMI)
       └── Restored EBS Data Volume (from replicated Snapshot)
                 (Attached, mounted, and symlinked to restore production orders)

🛠️ Step-by-Step Implementation & Validation
Phase 1: Decoupled Architecture & Baseline Setup (Mumbai)
To prevent data loss during stateless compute replacement, application storage was decoupled from the root OS disk:

Deployed an Ubuntu EC2 instance in ap-south-1 running Nginx.

Verified initial application state: the web server alerted that the persistent storage layer was missing.

Attached a dedicated 10 GiB gp3 EBS volume (/dev/nvme1n1).

Formatted the block device with an ext4 filesystem and mounted it to /production_data.

Created a filesystem symlink pointing /var/www/html/orders.txt to /production_data/orders.txt.

Verified production orders loaded dynamically and safely wrote to persistent block storage.

Phase 2: Compute & Storage Failure Simulations (In-Region)
1. Simulating Compute Failure (Instance Termination)
Intentionally terminated the primary EC2 instance to simulate an unrecoverable hardware or kernel crash.

Recovery: Spun up a replacement instance from the previously baked Golden AMI (devopsshack-base-ami). Reattached the surviving EBS data volume. Uptime was restored without configuration drift.

2. Simulating Data Corruption / Human Error
Simulated catastrophic human error by directly deleting active application records (sudo rm orders.txt).

Recovery: Detached the corrupted volume, restored a new volume directly from the last known good point-in-time EBS snapshot, and remounted it.

Phase 3: Cross-Region Disaster Recovery (Mumbai ➔ Hyderabad)
To protect against complete regional network or infrastructure outages:

Replication: Initiated cross-region transfers of the Golden AMI and the persistent data snapshot from ap-south-1 (Mumbai) to ap-south-2 (Hyderabad).

Cold Standby Deployment: Provisioned a DR EC2 instance in Hyderabad directly from the copied AMI.

Data Hydration: Created a new 10 GiB volume from the copied snapshot and attached it to the DR node.

Failover Verification: Successfully accessed the DR instance at http://18.60.44.80, validating complete order history and service availability.

📊 Resilience Metrics & Cost Governance
RTO (Recovery Time Objective): < 10 minutes (Time to launch from AMI, attach volume, and bind Nginx).

RPO (Recovery Point Objective): Bounded strictly by the snapshot schedule frequency.

Cost Optimization & Safety:

Configured an AWS Zero-Spend Budget alert to capture billing anomalies immediately.

Executed a complete post-validation teardown of all allocated volumes, snapshots, deregistered AMIs, and transient ENIs across both regions.
