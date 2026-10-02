# Lab 2 — Azure RBAC Access Control

**Owner · VM Contributor · Reader — Scoped to FS01 Only · Terraform + PowerShell**

> Taught and documented by Mr. Robot as part of the RBACAC 5-lab series.

## Business Context

Lab 1 solved *file-level* security: who can read or write files sitting on the FS01 file
server. This lab solves a different problem entirely — who can manage FS01 the
**virtual machine** itself, from the Azure control plane.

Picture a real IT organization:

- A **senior sysadmin** needs full control over the server — start, stop, resize,
  delete, and the ability to decide who else gets access.
- A **help desk technician** needs to restart the server when a user calls in saying
  it's unresponsive — but should never be able to delete it or touch its security
  configuration.
- An **auditor** needs to view the server's configuration for a compliance review —
  and should not be able to take any action on it at all.

Azure RBAC (Role-Based Access Control) is the mechanism that enforces this
separation at the infrastructure layer. Every action in Azure — starting a VM,
reading its config, assigning a role to someone else — requires a specific
permission, and RBAC lets you hand out exactly the permission a person's job
requires and nothing more. That's the principle of **least privilege**, applied to
cloud infrastructure instead of files.

### The scenario this lab simulates

A help desk ticket comes in: the Finance file server is unresponsive. The on-call
technician (**SupportTech**) logs into Azure and restarts the VM — but cannot delete
it, cannot change its configuration, and cannot see who else has access to it. Later,
an auditor (**Auditor**) runs a quarterly access review and exports the RBAC report
to prove only authorized people have access. After a staff change, the senior
sysadmin (**SysAdmin**) uses Owner rights to reassign roles. Each persona has
exactly what their job requires — no more.

## How This Lab Fits the Series

| Lab | What it deploys | Relationship |
|---|---|---|
| Lab 1 — NTFS File Server | DC01, FS01, CLIENT01, VNet, NSG, Key Vault in `RG-FileServerLab` | Standalone — builds all infrastructure from scratch |
| **Lab 2 — Azure RBAC** | 3 role assignments on FS01 only — no new VMs | **Depends on Lab 1** — reads Lab 1 resources via Terraform data sources, reuses Lab 1's storage account |
| AUM Lab — Azure Update Manager | DC01, WS01, WS02, VNet, Key Vault in `rg-aumlab` | Standalone — independent of Lab 1 and Lab 2 |

This lab deploys **zero new infrastructure**. It layers Azure-level access control on
top of the FS01 VM that Lab 1 already created. That's why `terraform plan` for this
project should never show a VM, a VNet, or a resource group — only role
assignments.

**Prerequisite:** Lab 1 must be fully deployed and running (`RG-FileServerLab` and
`FS01` must exist) before starting this lab.

## What You'll Learn

- The difference between **RBAC** (controls the infrastructure from outside — Azure
  Resource Manager) and **NTFS** (controls files inside the OS) — the two most
  commonly confused security layers when moving from on-prem to cloud
- How to scope a role assignment to a **single resource** instead of a whole
  resource group, to keep the blast radius small
- How to use Terraform **data sources** to safely reference another project's
  existing infrastructure without modifying it
- How to look up **Azure AD Object IDs** (and why email addresses aren't enough)
- How to test role enforcement by logging in **as each persona** with the Azure CLI
- How to produce a structured, exportable **validation/compliance report**

## Architecture

```
                 Azure Resource Manager — Control Plane
        RBAC enforced at resource scope — independent of NTFS

   ┌───────────┐        ┌────────────────┐        ┌───────────┐
   │   Owner   │        │ VM Contributor │        │  Reader   │
   │ SysAdmin  │        │  SupportTech   │        │ Auditor   │
   └─────┬─────┘        └───────┬────────┘        └─────┬─────┘
         │                      │                        │
         └──────────────┬───────┴────────────────────────┘
                         ▼
         Resource Group: RG-FileServerLab
   ┌─────────┐     ┌───────────────────┐     ┌────────────┐
   │  DC01   │     │       FS01        │     │ CLIENT01   │
   │no roles │     │ ← all 3 roles     │     │ no roles   │
   │assigned │     │   assigned here   │     │ assigned   │
   └─────────┘     └───────────────────┘     └────────────┘
```

All three role assignments are scoped to **FS01's resource ID only**. DC01 and
CLIENT01 sit in the same resource group but receive no assignments in this lab —
none of the three personas can manage them through Azure RBAC.

## Repo Structure

```
lab-02-azure-rbac/
├── README.md              ← you are here
├── SOP.md                 ← full runbook: steps, rationale, security callouts, troubleshooting
└── rbac-lab-terraform/    ← the deployable Terraform project
    ├── backend.tf
    ├── versions.tf
    ├── variables.tf
    ├── data.tf
    ├── rbac.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    ├── .gitignore
    ├── validate-lab.ps1
    └── scripts/
        └── 01-get-object-ids.ps1
```

## Screenshots

Fill these in as you work through `SOP.md`. Placeholders are numbered to match the
SOP steps.

- `![Step 6: terraform plan showing exactly 3 resources](screenshots/01-terraform-plan.png)`
- `![Step 6: terraform apply complete](screenshots/02-terraform-apply.png)`
- `![Azure Portal: FS01 → Access Control (IAM) showing 3 role assignments](screenshots/03-portal-iam.png)`
- `![Step 6: validate-lab.ps1 output — all PASS](screenshots/04-validate-lab-output.png)`
- `![Step 7: Auditor test — az vm show succeeds, az vm stop fails](screenshots/05-persona-test-auditor.png)`
- `![Step 7: SupportTech test — az vm start succeeds, role assignment list fails](screenshots/06-persona-test-supporttech.png)`
- `![Step 7: SysAdmin test — both commands succeed](screenshots/07-persona-test-sysadmin.png)`
- `![RBAC_Lab_Report.txt contents](screenshots/08-compliance-report.png)`

## Where to Start

Read `SOP.md` for the full step-by-step runbook — prerequisites, deployment,
validation, persona testing, teardown, and troubleshooting, with security callouts
and common-error notes built in throughout.
