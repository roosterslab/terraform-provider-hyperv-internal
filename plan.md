# hypervapiv2 — v2 Intuitive HCL Design (Copy‑ready)

> **Project:** New Terraform provider `hypervapiv2` (no backward compatibility with v1).
> **API Layer:** Hyper‑V Management API v2 (JEA/Policy backed).
> **Contracts:** RBAC enforced • strict path policy • convergent plans • descriptive errors.

This spec delivers an intuitive, user‑first HCL while retaining all capabilities: policy‑aware disk placement, every disk scenario (new/clone/attach), secure firmware & TPM, deterministic layouts, and plan‑time guidance.

---

## 1) Design Goals

* **Intuitive primitives**: natural names, human units (`"8GB"`, `"40GB"`).
* **Policy by construction**: implicit auto‑placement asks the API; explicit paths are validated at plan.
* **All disk scenarios**: new (auto/custom), clone (auto/custom), attach existing.
* **Plan‑time helpers**: data sources that *suggest*, *validate*, and *pre‑plan* VMs with reasons & warnings.
* **Safety rails**: provider enforcement (`enforce_policy_paths`, `strict`), disk‑level `protect`, deterministic `controller/lun`.

---

## 2) Quick Start

```hcl
terraform {
  required_providers {
    hypervapiv2 = {
      source  = "vinitsiriya/hypervapiv2"
      version = ">= 2.0.0"
    }
  }
}

variable "endpoint" { type = string }
variable "vm_name"  { type = string }

provider "hypervapiv2" {
  endpoint = var.endpoint

  auth {
    method = "negotiate"   # also: "bearer", "none"
    # username = "DOMAIN\\user"
    # password = "secret"
  }

  enforce_policy_paths = true  # plan fails if explicit path violates policy
  strict               = false # warnings escalate to plan errors when true

  defaults {
    cpu    = 2
    memory = "2GB"
    disk   = "20GB"
  }
}

resource "hypervapiv2_network" "lan" {
  name = "lan-internal"
  type = "Internal"           # Internal | Private | External
}

# Ask for a policy-aware OS disk location with rationale
data "hypervapiv2_disk_plan" "os" {
  vm_name   = var.vm_name
  operation = "create"        # create | clone | attach
  purpose   = "os"
  size_gb   = 50
}

resource "hypervapiv2_vm" "win" {
  name   = var.vm_name
  cpu    = 4
  memory = "6GB"
  power  = "running"

  disk {
    name       = "os"
    purpose    = "os"
    boot       = true
    path       = data.hypervapiv2_disk_plan.os.path
    size       = "50GB"
    type       = "dynamic"
    controller = "SCSI"
    lun        = 0
  }

  network_interface { switch = hypervapiv2_network.lan.name }

  firmware { secure_boot = true }
  security { tpm = true, encrypt = false }

  lifecycle { delete_disks = false }
}
```

---

## 3) Provider Schema

```hcl
provider "hypervapiv2" {
  endpoint = "http://localhost:5006"

  auth {
    method   = "negotiate"   # bearer | none
    # username = ""
    # password = ""
  }

  proxy                = null
  timeout_seconds      = 60
  enforce_policy_paths = true   # plan-time check for explicit disk paths
  strict               = false  # treat policy warnings as plan errors when true

  defaults {
    cpu    = 2
    memory = "2GB"
    disk   = "20GB"
  }
}
```

**Notes**

* If a disk only specifies `size`, provider auto‑queries the API for a policy‑compliant path.
* Explicit `path`/`source_path` are validated at plan (and will fail if outside policy roots/extensions when `enforce_policy_paths = true`).

---

## 4) Resources

### 4.1 `hypervapiv2_network`

Create a Hyper‑V vSwitch.

```hcl
resource "hypervapiv2_network" "lan" {
  name = "lan-internal"
  type = "Internal"  # Internal | Private | External
  # tags = { env = "lab" }  # optional
}
```

**Args**: `name` (required), `type` (required), optional `tags` (map).

---

### 4.2 `hypervapiv2_vm`

Unified VM with disks, NICs, firmware, security, lifecycle.

```hcl
resource "hypervapiv2_vm" "app" {
  name   = "app01"
  cpu    = 4
  memory = "8GB"
  power  = "running"                 # running | stopped
  stop_method          = "graceful"  # graceful | force | turnoff
  wait_timeout_seconds = 240

  # ===== DISKS (all scenarios) =====

  # 1) New (auto path)
  disk {
    name    = "cache"
    purpose = "ephemeral"
    size    = "40GB"
    placement {
      min_free_gb = 10
    }
  }

  # 2) New (custom path)
  disk {
    name     = "data"
    purpose  = "data"
    path     = "D:/HyperV/VMs/app01/data.vhdx"
    size     = "100GB"
    type     = "fixed"
    protect  = true                # never delete this disk via TF
    placement {
      prefer_root   = "D:/HyperV/VMs"
      co_locate_with = "os"
    }
  }

  # 3) Clone (auto path)
  disk {
    name       = "clone_auto"
    purpose    = "os"
    clone_from = "D:/HyperV/Templates/win11-base.vhdx"
  }

  # 4) Clone (custom path)
  disk {
    name       = "clone_custom"
    purpose    = "os"
    clone_from = "D:/HyperV/Templates/win11-base.vhdx"
    path       = "D:/HyperV/VMs/app01/clone.vhdx"
  }

  # 5) Attach existing
  disk {
    name        = "shared"
    purpose     = "data"
    source_path = "D:/HyperV/Shared/shared-data.vhdx"
    read_only   = false
  }

  # Optional deterministic layout per-disk
  # controller = "SCSI" | "IDE"  (default SCSI)
  # lun        = 0..63

  # ===== NETWORK =====
  network_interface {
    name         = "eth0"
    switch       = hypervapiv2_network.lan.name
    mac_address  = null
    is_connected = true
    # vlan_id    = 100
  }

  # ===== FIRMWARE =====
  firmware {
    secure_boot = true
    # secure_boot_template = "MicrosoftWindows"
    # boot_device          = "Disk" | "CD"
    # boot_order           = ["Disk", "CD", "Network"]
    # first_boot_application = "..."
  }

  # ===== SECURITY =====
  security {
    tpm     = true
    encrypt = false
  }

  # ===== LIFECYCLE =====
  lifecycle {
    delete_disks = false         # deletes provider-owned VHDX only (if true & policy allows)
  }

  # Optional discovery aid
  # tags     = { app = "billing", env = "prod" }
  # metadata = { owner = "ops@example.com" }
}
```

**Top‑level VM**: `name`, `cpu`, `memory`, `power`, `stop_method`, `wait_timeout_seconds`, optional `tags`, `metadata`.

**`disk {}`** (self‑describing & complete)

* **Pick a scenario by fields**

  * New (auto): `size`
  * New (custom): `size` + `path`
  * Clone (auto): `clone_from`
  * Clone (custom): `clone_from` + `path`
  * Attach: `source_path`
* **Common attributes**: `name`, `purpose = "os"|"data"|"ephemeral"`, `type = "dynamic"|"fixed"`, `boot`, `controller`, `lun`, `read_only`, `auto_attach` (default `true`), `protect`.
* **Placement hints** (optional):

  ```hcl
  placement {
    prefer_root    = "D:/HyperV/VMs"
    min_free_gb    = 20
    co_locate_with = "os"   # name of another disk in this VM
  }
  ```

---

## 5) Data Sources (Intuitive, Plan‑time)

> Names are short and action‑oriented. All return normalized values, reasons, and warnings.

### 5.1 `hypervapiv2_disk_plan` — *Suggest a compliant path*

```hcl
data "hypervapiv2_disk_plan" "os" {
  vm_name   = var.vm_name
  operation = "create"      # create | clone | attach
  purpose   = "os"
  size_gb   = 50             # required for create
  # clone_from   = "D:/HyperV/Templates/base.vhdx"  # required for clone

  # Optional hints
  prefer_root    = "D:/HyperV/VMs"
  min_free_gb    = 20
  co_locate_with = "os"
  ext            = ".vhdx"
}
```

**Outputs**: `path`, `reason`, `matched_root`, `normalized_path`, `writable`, `free_gb_after`, `host`, `warnings[]`.

---

### 5.2 `hypervapiv2_path_validate` — *Is this path allowed?*

```hcl
data "hypervapiv2_path_validate" "custom" {
  path      = "D:/HyperV/VMs/${var.vm_name}/os.vhdx"
  operation = "create"    # create | clone | attach
  ext       = ".vhdx"
}
```

**Outputs**: `allowed` (bool), `matched_root`, `normalized_path`, `message`, `violations[]`.

---

### 5.3 `hypervapiv2_vm_plan` — *Pre‑solve an entire VM*

```hcl
data "hypervapiv2_vm_plan" "p" {
  vm_name = var.vm_name
  cpu     = 4
  memory  = "8GB"

  disks = [
    { name = "os",   purpose = "os",   size = "50GB", boot = true },
    { name = "logs", purpose = "data", size = "100GB", placement = { co_locate_with = "os" } }
  ]

  network { switch = "lan-internal" }
}
```

**Outputs**:

* `resolved.cpu`, `resolved.memory_mb`
* `resolved.disks[]` → `{ name, path, mode, controller, lun, reason, warnings[] }`
* `resolved.network[]` → `{ switch, mac_suggested }`
* `warnings[]`, `errors[]`

> Use outputs to feed `hypervapiv2_vm` for deterministic, policy‑clean applies.

---

### 5.4 `hypervapiv2_policy` — *Summarize effective rules*

```hcl
data "hypervapiv2_policy" "effective" {}
```

**Outputs**: `roots[]`, `extensions[]`, `quotas{root:{max_gb,used_gb,free_gb}}`, `name_patterns{vm,switch}`, `deny_reasons{}`.

---

### 5.5 `hypervapiv2_whoami` — *RBAC identity*

```hcl
data "hypervapiv2_whoami" "me" {}
```

**Outputs**: `user`, `domain`, `sid`, `groups[]`.

---

### 5.6 `hypervapiv2_host_info` — *Capabilities & storage snapshot*

```hcl
data "hypervapiv2_host_info" "cap" {}
```

**Outputs**:
`tpm_supported`, `encryption_toggle_supported`, `secure_boot_templates[]`, `max_vcpu`, `storage_roots[] { root, total_gb, free_gb }`, `clustered`, `host`.

---

### 5.7 `hypervapiv2_vm_shape` — *Preset sizing*

```hcl
data "hypervapiv2_vm_shape" "medium" { name = "medium" }
```

**Outputs**: `cpu`, `memory`, optional `disk_default`.

---

### 5.8 `hypervapiv2_images` — *Discover base images*

```hcl
data "hypervapiv2_images" "base" {
  # filter_name = "Win11"
  # under_root  = "D:/HyperV/Templates"
  # with_tag    = "windows"
}
```

**Outputs**: `images[] { path, size_gb, created, tags[], notes }`.

---

### 5.9 `hypervapiv2_name_check` — *Validate names (with suggestions)*

```hcl
data "hypervapiv2_name_check" "vm" {
  kind = "vm"   # vm | switch
  name = var.vm_name
}
```

**Outputs**: `allowed` (bool), `message`, `pattern`, `suggestions[]`.

---

## 6) Patterns That Feel Natural

### A) Recommend → Validate → Use

```hcl
data "hypervapiv2_disk_plan" "os" {
  vm_name   = var.vm_name
  operation = "create"
  purpose   = "os"
  size_gb   = 50
}

data "hypervapiv2_path_validate" "os" {
  path      = data.hypervapiv2_disk_plan.os.path
  operation = "create"
}

resource "hypervapiv2_vm" "vm" {
  name   = var.vm_name
  cpu    = 4
  memory = "8GB"
  power  = "stopped"

  disk {
    name    = "os"
    purpose = "os"
    boot    = true
    path    = data.hypervapiv2_disk_plan.os.path
    size    = "50GB"
  }

  lifecycle {
    precondition {
      condition     = data.hypervapiv2_path_validate.os.allowed
      error_message = "OS disk path denied: ${data.hypervapiv2_path_validate.os.message}"
    }
  }
}
```

### B) Whole‑VM preflight

```hcl
data "hypervapiv2_vm_plan" "p" {
  vm_name = var.vm_name
  cpu     = 4
  memory  = "8GB"

  disks = [
    { name = "os", size = "50GB", purpose = "os", boot = true },
    { name = "data", size = "100GB", purpose = "data", placement = { co_locate_with = "os" } }
  ]

  network { switch = "lan-internal" }
}

resource "hypervapiv2_vm" "vm" {
  name   = var.vm_name
  cpu    = data.hypervapiv2_vm_plan.p.resolved.cpu
  memory = "${data.hypervapiv2_vm_plan.p.resolved.memory_mb}MB"
  power  = "stopped"

  disk {
    name       = "os"
    purpose    = "os"
    boot       = true
    path       = data.hypervapiv2_vm_plan.p.resolved.disks[0].path
    size       = "50GB"
    controller = data.hypervapiv2_vm_plan.p.resolved.disks[0].controller
    lun        = data.hypervapiv2_vm_plan.p.resolved.disks[0].lun
  }

  disk {
    name    = "data"
    purpose = "data"
    path    = data.hypervapiv2_vm_plan.p.resolved.disks[1].path
    size    = "100GB"
  }

  network_interface { switch = data.hypervapiv2_vm_plan.p.resolved.network[0].switch }
  firmware { secure_boot = true }
  security { tpm = true, encrypt = false }
}
```

---

## 7) Behavior & Safety

* **Policy always on**: explicit paths validated at plan; implicit paths come from API suggestions.
* **Strict mode**: `strict = true` escalates warnings (e.g., low free space) to plan errors.
* **Delete semantics**:

  * `delete_disks = true` removes **provider‑owned** VHDX only (never `source_path` attachments).
  * `disk.protect = true` prevents deletion even if enabled above.
* **State truth**: provider re‑reads host state after apply for accurate Terraform state.

---

## 8) Errors (clear mapping)

| HTTP | Meaning           | Action                                               |
| ---- | ----------------- | ---------------------------------------------------- |
| 401  | Unauthorized      | Fix `auth` block / credentials                       |
| 403  | Policy/JEA denial | Outside roots, disallowed cmdlet, RBAC               |
| 409  | Conflict/busy     | Tune `stop_method` / timeouts                        |
| 400  | Host limitation   | E.g., cannot toggle Encryption Support; disable flag |

---

## 9) API Mapping (mental model)

* Disk create (auto/custom) → `POST /vhdx/create`
* Disk clone  (auto/custom) → `POST /vhdx/clone`
* Disk attach               → `POST /vm/attach-vhd`
* NIC ops                   → `POST /vm/nic`
* Firmware                  → `POST /vm/firmware`
* Security                  → `POST /vm/security`
* Power                     → `POST /vm/power`
* Switch                    → `POST /vswitch`
* Plans/validation          → `POST /policy/plan-disk`, `POST /policy/validate-path`, `POST /policy/vm-plan`

---

## 10) Why this is "more intuitive" without losing power

* **Action‑oriented data sources**: plan → validate → apply, all with reasons & warnings.
* **Disk blocks read like intent**: purpose, boot, placement, layout — not low‑level API verbs.
* **Deterministic when needed**: controller/LUN, `protect`, `auto_attach`.
* **Policy‑centric UX**: first‑class suggestions, checks, and strict mode.

---

## 11) Migration Note (v1 → v2 project)

* `hypervapiv2` is a **separate provider**. v1 remains alive and unchanged.
* v2 consolidates common flows in `hypervapiv2_vm` and introduces clearer data sources: `disk_plan`, `path_validate`, `vm_plan`.
* Keep using plan‑time helpers to make modules predictable and policy‑clean.
