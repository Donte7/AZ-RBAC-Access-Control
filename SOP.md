# SOP / Runbook — Lab 2: Azure RBAC Access Control

**Reference:** RBAC-LAB-002
**Depends on:** Lab 1 (NTFS File Server) — `RG-FileServerLab` and `FS01` must exist and be running
**Deploy time:** Under 1 minute · **Cost:** Free (role assignments carry no charge — only Lab 1's VMs incur compute cost)

This runbook walks through deploying, validating, and tearing down Lab 2. Security
callouts (🔒) and common-error notes (⚠️) are placed inline at the point where they're
relevant, not bolted on at the end.

---

## 0. Prerequisites — Verify Before Starting

```powershell
terraform -version   # Must be >= 1.5.0
az version            # Azure CLI — any recent version

# Confirm correct subscription
az account show
# If wrong: az account set --subscription "<name or ID>"

# Confirm Lab 1 VMs are running
az vm list -g RG-FileServerLab --query "[].{name:name,status:powerState}" -o table
# All three must show: VM running
# If stopped: az vm start --ids $(az vm list -g RG-FileServerLab --query "[].id" -o tsv)
```

🔒 **Security callout:** confirming your active subscription with `az account show`
before running any Terraform apply is not a formality. Applying against the wrong
subscription is a common way role assignments end up granted in the wrong tenant
or environment — and `terraform destroy` later will happily tear down whatever it
finds in *that* subscription's state.

---

## 1. Create Your Project Folder

Lab 2 is a **separate, independent Terraform project** from Lab 1, even though it
reads Lab 1's resources. Never share a folder or a state key between the two.

```powershell
New-Item -ItemType Directory -Path "$HOME\rbac-lab-terraform"
cd "$HOME\rbac-lab-terraform"
New-Item -ItemType Directory -Path scripts
```

Target structure:

```
rbac-lab-terraform/
├── backend.tf                  ← reuses Lab 1 storage account, different state key
├── versions.tf                 ← provider version requirements
├── variables.tf                ← three Object ID inputs with no defaults
├── data.tf                     ← reads Lab 1 resource group and FS01 without modifying them
├── rbac.tf                     ← the three role assignments scoped to FS01
├── outputs.tf                  ← VM ID, resource group, role assignment IDs
├── terraform.tfvars.example    ← safe template, commit this
├── terraform.tfvars            ← your real Object IDs — never commit this
├── .gitignore
├── validate-lab.ps1            ← confirms assignments, prints permission matrix, exports report
└── scripts/
    └── 01-get-object-ids.ps1   ← translates user emails to Azure AD Object IDs
```

⚠️ **Common error:** putting Lab 2's files inside the Lab 1 folder, or reusing Lab 1's
state key. If both labs share a state key, running `terraform destroy` in Lab 2 will
also destroy Lab 1's VMs, VNet, and NSG. Separate folder, separate state key —
always.

---

## 2. Create the Terraform Files

All six files (`backend.tf`, `versions.tf`, `variables.tf`, `data.tf`, `rbac.tf`,
`outputs.tf`) plus `terraform.tfvars.example` and `.gitignore` are provided in
`rbac-lab-terraform/` in this repo — copy them as-is or regenerate them locally.

Key points to understand as you review them:

- **`data.tf`** reads Lab 1's resource group and the FS01 VM *without modifying
  either*. This is how Lab 2 "sees" Lab 1's infrastructure. If Lab 1 isn't deployed,
  Terraform stops with a clear error before planning anything — no silent partial
  apply.
- **`rbac.tf`** — the `scope` field on each `azurerm_role_assignment` is the single
  most important line in the whole project. It points at FS01's specific resource
  ID, not the resource group's ID.
  🔒 **Security callout:** if `scope` were set to the resource group ID instead of
  the VM's resource ID, every one of these three roles would silently apply to
  **every resource in `RG-FileServerLab`** — DC01 and CLIENT01 included. Scoping to
  the narrowest possible resource is what limits blast radius if one of these
  accounts is ever compromised.
- **`variables.tf`** — the three Object ID variables (`sysadmin_object_id`,
  `support_user_object_id`, `auditor_object_id`) deliberately have **no default
  values**. 🔒 **Security callout:** if they had defaults, a careless `terraform
  apply` could assign real roles to a placeholder or leftover identity without
  ever raising an error. No default means Terraform refuses to run until you
  supply real values.

⚠️ **Common error:** copying `backend.tf` from Lab 1 verbatim. The `storage_account_name`
must match Lab 1's real value, and the `key` **must** be `rbac-lab.terraform.tfstate`
(Lab 1 uses `ntfs-lab.terraform.tfstate`). Same container, different key — if the keys
match, you're sharing state with Lab 1 by accident.

---

## 3. Create the Scripts

Copy `validate-lab.ps1` into the project root and `scripts/01-get-object-ids.ps1` into
the `scripts/` subfolder (both provided in this repo).

- **`01-get-object-ids.ps1`** — Terraform needs each user's Azure AD **Object ID**
  (a GUID), not their email address. Object IDs are immutable; email addresses can
  change (e.g., a name change or domain migration), which would silently break a
  role assignment tied to an email instead of an ID. This script prompts for each
  UPN and prints the three lines you paste into `terraform.tfvars`.
- **`validate-lab.ps1`** — confirms the three role assignments are actually live in
  Azure (not just that Terraform *said* it created them — those are two different
  systems, since RBAC propagation can lag behind the apply by several minutes),
  prints a PASS/FAIL permission matrix, and exports `RBAC_Lab_Report.txt` as
  compliance evidence.

⚠️ **Common error:** running `validate-lab.ps1` immediately after `terraform apply`
and panicking at FAIL results. RBAC propagation can take 2–10 minutes depending on
the tenant. Wait and re-run before assuming something is actually broken.

---

## 4. Prepare Your Test Users

You need **three existing Azure AD accounts** — test accounts, not your own daily
driver account.

| Role assigned | User UPN (email) | Object ID (fill in after Step 5) |
|---|---|---|
| SysAdmin — Owner | | |
| SupportTech — VM Contributor | | |
| Auditor — Reader | | |

🔒 **Security callout on test accounts:** never run this lab's persona tests
against production admin accounts. Use dedicated, disposable test identities so
that a mistake (e.g., accidentally granting Owner broadly) has no real blast
radius, and so you can safely delete the accounts after teardown.

⚠️ **MFA note:** Step 7 requires `az login` as each test user. If your tenant
enforces MFA, either create these accounts with a Conditional Access exclusion or
use a test tenant without MFA.

```powershell
# Run this — it prompts for three UPNs and prints Object IDs to paste into tfvars
.\scripts\01-get-object-ids.ps1
```

---

## 5. Configure Variables

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars

# Open terraform.tfvars and paste in the three Object IDs from Step 4
# Confirm resource_group_name = "RG-FileServerLab" matches Lab 1 exactly
# Confirm vm_name = "FS01" matches Lab 1 exactly

# Open backend.tf and replace REPLACE_WITH_YOUR_LAB1_STORAGE_ACCOUNT_NAME
```

⚠️ **Common error:** case mismatches. `FS01` is not the same as `fs01` to Azure
Resource Manager's data source lookups in this context — keep capitalization exact
to what Lab 1 actually deployed.

🔒 **Security callout:** never commit `terraform.tfvars` — it holds real Object
IDs tied to real identities. `.gitignore` in this project already excludes it and
allows only `terraform.tfvars.example` (which contains placeholder text, safe to
commit).

---

## 6. Deploy and Validate

```powershell
az login && az account show
terraform init
terraform plan     # Must show exactly 3 resources — no VMs, no networking, no resource groups
terraform apply    # Type yes — completes in under 1 minute

# Wait 2–3 minutes for RBAC to propagate, then validate
.\validate-lab.ps1
# Confirms all 3 assignments, prints permission matrix, exports RBAC_Lab_Report.txt
```

📸 *Screenshot placeholders: `01-terraform-plan.png`, `02-terraform-apply.png`,
`03-portal-iam.png`, `04-validate-lab-output.png`*

⚠️ **If `terraform plan` shows more than 3 resources:** stop. Check
`terraform.tfvars` — `resource_group_name` and `vm_name` must be an exact,
case-sensitive match to the Lab 1 deployment. A mismatch usually means Terraform
resolved a data source you didn't expect, or fell back to a default that doesn't
point at your real Lab 1 resources.

---

## 7. Test As Each Persona

Open a new terminal per test. Log in as the test user, run the commands, confirm
the expected result, then close that terminal. **The FAIL results are not
errors — they're proof the role enforcement is working.**

```powershell
# ── Test 1: Auditor — Reader ──────────────────────────────
az login    # Log in as your Auditor test account

az vm show -g RG-FileServerLab -n FS01 --query "{name:name,size:hardwareProfile.vmSize}"
# Expected: SUCCEEDS — Reader can view VM details

az vm stop -g RG-FileServerLab -n FS01
# Expected: FAILS — AuthorizationFailed
# This failure confirms Reader is working. Auditor cannot stop VMs.

# ── Test 2: SupportTech — VM Contributor ──────────────────
az login    # Log in as your SupportTech test account

az vm start -g RG-FileServerLab -n FS01
# Expected: SUCCEEDS — VM Contributor can start VMs

az role assignment list --scope $(az vm show -g RG-FileServerLab -n FS01 --query id -o tsv)
# Expected: FAILS — AuthorizationFailed
# SupportTech cannot view or manage RBAC assignments.

# ── Test 3: SysAdmin — Owner ──────────────────────────────
az login    # Log in as your SysAdmin test account

az vm show -g RG-FileServerLab -n FS01 --query "{name:name}"
# Expected: SUCCEEDS

az role assignment list --scope $(az vm show -g RG-FileServerLab -n FS01 --query id -o tsv)
# Expected: SUCCEEDS — Owner can view and manage RBAC assignments

# ── Restore your own account ──────────────────────────────
az login    # Log back in as your own account
az account show    # Confirm your subscription is active
```

📸 *Screenshot placeholders: `05-persona-test-auditor.png`,
`06-persona-test-supporttech.png`, `07-persona-test-sysadmin.png`*

🔒 **Security callout:** this step is the whole point of the lab. Terraform saying
"apply complete" tells you a role assignment *object* exists. It does not by
itself prove enforcement. Logging in *as* each identity and confirming both what
succeeds and what correctly fails is how you actually demonstrate least privilege
— and it's exactly what an auditor will ask you to reproduce.

---

## 8. Teardown

```powershell
# Option A — remove RBAC only, keep Lab 1 VMs running
terraform destroy

# Option B — full teardown, completely done with both labs
terraform destroy                                       # Remove RBAC first
az group delete -n RG-FileServerLab --yes --no-wait     # Remove all Lab 1 resources
az group show -n RG-FileServerLab 2>&1                  # Expect: ResourceGroupNotFound
```

⚠️ **Common error:** running `az group delete` before `terraform destroy`. If you
delete the resource group first, Terraform's state file still references role
assignments on a VM that no longer exists — `terraform destroy` will then error or
leave orphaned state entries. Destroy Lab 2's RBAC first, then tear down Lab 1's
resource group.

---

## Troubleshooting

| Problem | Cause | Solution |
|---|---|---|
| `terraform apply`: principal not found | Object ID is wrong or the account was deleted | Re-run `01-get-object-ids.ps1`, update `terraform.tfvars`, re-apply |
| `terraform apply`: resource group not found | Lab 1 is not deployed | Deploy the NTFS lab first — `RG-FileServerLab` must exist |
| `validate-lab.ps1` shows FAIL after 10+ minutes | Role assignment not actually in Terraform state | Run `terraform state list` — confirm three `azurerm_role_assignment` resources appear. If missing, re-apply |
| `az vm stop` succeeds for Auditor | RBAC still propagating | Wait 5 minutes and retest |
| Plan shows more than 3 resources | `resource_group_name` or `vm_name` mismatch | Check capitalization — `FS01` is not the same as `fs01` |
| MFA prompt when logging in as test user | Tenant enforces MFA | Create a Conditional Access exclusion for test accounts, or use a test tenant without MFA |

---

## Concepts Recap (why this lab matters beyond the lab)

- **RBAC vs. NTFS:** RBAC governs the infrastructure from the outside (Azure
  Resource Manager control plane); NTFS governs files from inside the OS. A file
  server can have flawless NTFS permissions and still be a risk if anyone with a
  portal login can start, stop, or delete the VM itself. Both layers must be
  configured — neither substitutes for the other.
- **Scope is the control:** the same role (e.g., Contributor) means something
  very different depending on whether it's scoped to a subscription, a resource
  group, or a single resource. Narrower scope = smaller blast radius if an
  identity is compromised.
- **Terraform data sources** are the standard pattern for letting one team's
  Terraform project safely read another team's infrastructure without owning or
  modifying it — each project keeps its own state and its own lane.
- **Verification is not optional.** "Terraform said it worked" and "Azure actually
  enforces it" are two different claims. Professional RBAC work always includes a
  validation step, ideally one that produces an artifact (a report) you can hand
  to an auditor.
