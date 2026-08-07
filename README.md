# OCI Terraform — Week 1 Lab

Terraform configuration that builds a small, self-contained lab environment in **Oracle Cloud Infrastructure (OCI)**: a virtual network with internet access, one Oracle Linux 9 compute instance reachable over SSH, and a block volume attached to it.

Everything is defined as code — one `terraform apply` builds the whole stack, one `terraform destroy` removes it.

---

## What gets created

| # | Resource | Terraform address | Display name in OCI | Purpose |
|---|----------|-------------------|---------------------|---------|
| 1 | VCN | `oci_core_vcn.lab_vcn` | `salem-lab-vcn` | Private network, `10.0.0.0/16` |
| 2 | Internet Gateway | `oci_core_internet_gateway.lab_igw` | `salem-lab-igw` | Gives the VCN a path to the public internet |
| 3 | Route Table | `oci_core_route_table.lab_route_table` | `salem-lab-route-table` | Sends `0.0.0.0/0` (all outbound) to the IGW |
| 4 | Security List | `oci_core_security_list.lab_security_list` | `salem-lab-security-list` | Virtual firewall: allows inbound TCP 22 (SSH), allows all outbound |
| 5 | Public Subnet | `oci_core_subnet.lab_public_subnet` | `salem-lab-public-subnet` | `10.0.0.0/24`, public IPs allowed, uses the route table + security list above |
| 6 | Compute Instance | `oci_core_instance.lab_instance` | `salem-lab-instance` | Oracle Linux 9 VM, `VM.Standard.E5.Flex` (1 OCPU / 12 GB by default) |
| 7 | Block Volume | `oci_core_volume.lab_block_volume` | `salem-lab-block-volume` | 50 GB extra disk |
| 8 | Volume Attachment | `oci_core_volume_attachment.lab_volume_attachment` | — | Attaches the volume to the instance (paravirtualized) |

Every display name is built as `"${var.lab_name}-<role>"`, so renaming the whole lab is a one-line change to `lab_name`.

Plus two **data sources** (read-only lookups, nothing is created):

- `data.oci_identity_availability_domains.domains` — lists the availability domains in your region
- `data.oci_core_images.ol9` — finds the newest Oracle Linux 9 image that supports the chosen shape

### How the pieces connect

```
                    Internet
                        │
                        ▼
            ┌───────────────────────┐
            │  Internet Gateway     │
            └───────────┬───────────┘
                        │  (0.0.0.0/0)
            ┌───────────▼───────────┐
            │     Route Table       │
            └───────────┬───────────┘
                        │
  VCN 10.0.0.0/16       │
  ┌─────────────────────▼─────────────────────┐
  │  Public Subnet 10.0.0.0/24                │
  │  (Security List: inbound 22, outbound all)│
  │                                           │
  │   ┌─────────────────────────────┐         │
  │   │  Compute Instance           │         │
  │   │  Oracle Linux 9             │◄── SSH ─┼── you
  │   │  VNIC + public IP           │         │
  │   └──────────────┬──────────────┘         │
  │                  │ attachment             │
  │   ┌──────────────▼──────────────┐         │
  │   │  Block Volume (50 GB)       │         │
  │   └─────────────────────────────┘         │
  └───────────────────────────────────────────┘
```

Terraform works out this ordering automatically from the references between resources — you never declare "build the VCN first". For example, the subnet references `oci_core_vcn.lab_vcn.id`, so the VCN must exist before the subnet.

---

## File structure

```
oci-terraform-week1/
├── provider.tf                 # Terraform + OCI provider setup
├── variables.tf                # Input variables (the knobs you can turn)
├── network.tf                  # VCN, IGW, route table, security list, subnet
├── compute.tf                  # Data lookups, instance, block volume, attachment
├── outputs.tf                  # Values printed after apply
├── moved.tf                    # Rename history (see below) — deletable after apply
├── terraform.tfvars            # Your real values (gitignored)
├── terraform.tfvars.example    # Template for your own terraform.tfvars
├── .gitignore                  # Excludes state, tfvars, keys, .terraform/
├── .terraform.lock.hcl         # Locked provider versions (commit this)
├── .terraform/                 # Downloaded providers (do NOT commit)
└── README.md                   # This file
```

Terraform loads **every** `.tf` file in the directory and merges them into one configuration. The split into `network.tf` / `compute.tf` / etc. is purely for human readability — the filenames have no special meaning to Terraform (except `terraform.tfvars`, see below).

### `provider.tf` — setup

```hcl
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    oci = { source = "oracle/oci", version = "~> 7.0" }
  }
}

provider "oci" {
  config_file_profile = "DEFAULT"
  region              = var.oci_region
}
```

- `required_providers` pins the OCI provider to the 7.x line (`~> 7.0` allows 7.1, 7.32… but not 8.0).
- `required_version` refuses to run on Terraform older than 1.3.0.
- `config_file_profile = "DEFAULT"` means **credentials are read from `~/.oci/config`**, not from this repo. No keys or OCIDs live in the Terraform code. On Windows that file is at `C:\Users\<you>\.oci\config`.

### `variables.tf` — inputs

Every value you might want to change lives here, each with a `type` and (mostly) a `default`.

| Variable | Type | Default | Notes |
|----------|------|---------|-------|
| `lab_name` | string | `salem-lab` | Prefix for every resource's display name |
| `oci_region` | string | `me-jeddah-1` | OCI region identifier |
| `compartment_id` | string | *(none — required)* | Which compartment to build in |
| `ssh_pubkey_file` | string | `C:/salem-oci/ssh-key-2026-08-07.key.pub` | Path to your **public** key (`.pub`) |
| `vcn_cidr` | string | `10.0.0.0/16` | VCN address range |
| `subnet_cidr` | string | `10.0.0.0/24` | Subnet range, must sit inside the VCN range |
| `vm_shape` | string | `VM.Standard.E5.Flex` | Flex shape → CPU/RAM are configurable |
| `vm_ocpus` | number | `1` | vCPUs (1 OCPU ≈ 2 vCPU threads) |
| `vm_memory_gb` | number | `12` | RAM |
| `volume_size_gb` | number | `50` | Extra disk size (OCI minimum is 50) |

`compartment_id` has **no default**, so Terraform will refuse to run until you supply it. That is deliberate — it is the one value that is specific to your tenancy.

### `network.tf` — networking

Read it top to bottom; each resource builds on the one above.

- **VCN** — the private network. `dns_label` enables internal DNS names inside the VCN. It is **immutable in OCI**, so it keeps its original value (`lab1vcntf`) rather than following `var.lab_name` — changing it would force the VCN and everything in it to be rebuilt. Same applies to the subnet's `publicsubtf`.
- **Internet Gateway** — the door to the internet. Creating it is not enough; traffic only flows once a route table points at it.
- **Route Table** — one rule: destination `0.0.0.0/0` (everything) → `network_entity_id` = the IGW. This is what makes the subnet "public".
- **Security List** — OCI's stateful firewall at subnet level:
  - `egress`: destination `0.0.0.0/0`, protocol `all` → the VM can reach anything (needed for `yum update`, etc.)
  - `ingress`: source `0.0.0.0/0`, protocol `6` (TCP), ports 22–22 → SSH from anywhere
  - Protocol numbers are IANA values: `1` = ICMP, `6` = TCP, `17` = UDP, `"all"` = everything.
- **Subnet** — ties it together: it lives in the VCN, uses that route table and security list, and `prohibit_public_ip_on_vnic = false` permits instances in it to get public IPs.

### `compute.tf` — the machine

- **`data "oci_identity_availability_domains"`** — queries your region's ADs. The instance uses `...availability_domains[0].name`, i.e. the first AD. Some regions (including single-AD ones) only have one.
- **`data "oci_core_images"`** — searches for Oracle Linux 9 images compatible with `var.vm_shape`, sorted by creation time descending, so `images[0]` is always the **latest** image. This means you get current patches on every fresh apply without hardcoding an image OCID.
- **`oci_core_instance`** — the VM:
  - `shape_config` sets OCPUs and memory (only valid for `.Flex` shapes).
  - `create_vnic_details` puts the VM's network card in the public subnet with `assign_public_ip = true`.
  - `source_details` boots from the image found above.
  - `metadata.ssh_authorized_keys = file(var.ssh_pubkey_file)` — `file()` reads the `.pub` file from disk at apply time and injects it, so cloud-init installs it for the `opc` user. **Only the public key ever leaves your machine.**
- **`oci_core_volume` + `oci_core_volume_attachment`** — a separate 50 GB disk, attached as `paravirtualized`. Paravirtualized attachments appear as a normal block device with no iSCSI login commands needed; you still have to partition/format/mount it inside the OS the first time (`lsblk`, `mkfs.xfs`, `mount`).

### `outputs.tf` — results

Printed after `terraform apply`, and retrievable any time with `terraform output`:

- `instance_public_ip` — the IP to SSH into
- `instance_id`, `vcn_id`, `subnet_id`, `block_volume_id` — OCIDs of the created resources
- `ssh_connection_command` — a copy-paste SSH command. The private key path is derived with `trimsuffix(var.ssh_pubkey_file, ".pub")`, so it stays correct if you point at a different key.

### `moved.tf` — rename history

Terraform tracks resources by their address (`oci_core_vcn.lab_vcn`). Renaming a resource in the config normally reads as "destroy the old one, create a new one". A `moved` block tells Terraform the resource is the same one under a new name, so it updates state instead:

```hcl
moved {
  from = oci_core_vcn.lab1_vcn
  to   = oci_core_vcn.lab_vcn
}
```

These map the original `lab1_*` names onto the current `lab_*` ones. Once you've applied and state is on the new addresses, the file can be deleted.

---

## Prerequisites

1. **Terraform** ≥ 1.3.0 — verified working with v1.15.8 / OCI provider v7.32.0
2. **An OCI account** with permission to create networking + compute in the target compartment
3. **OCI CLI config** at `~/.oci/config` with a `DEFAULT` profile:
   ```ini
   [DEFAULT]
   user=ocid1.user.oc1..xxxx
   fingerprint=aa:bb:cc:...
   key_file=C:/path/to/your_api_private_key.pem
   tenancy=ocid1.tenancy.oc1..xxxx
   region=me-jeddah-1
   ```
   Generate this from the OCI Console: **Profile → My profile → API keys → Add API key**, then copy the shown config snippet.
4. **An SSH key pair** for logging into the VM (separate from the API key above):
   ```bash
   ssh-keygen -t rsa -b 4096 -f C:/salem-oci/oci-lab-key
   ```
   This produces `oci-lab-key` (private — keep it) and `oci-lab-key.pub` (public — the path you give Terraform).

---

## Usage

```bash
# 1. Create your variables file from the template
cp terraform.tfvars.example terraform.tfvars
#    then edit terraform.tfvars: put in your real compartment OCID and key path

# 2. Download the OCI provider (run once per directory)
terraform init

# 3. Check the config is valid and well-formatted
terraform validate
terraform fmt

# 4. Preview what will be created — nothing is changed yet
terraform plan

# 5. Build it (type "yes" at the prompt)
terraform apply

# 6. Connect
terraform output ssh_connection_command
ssh -i C:/salem-oci/oci-lab-key opc@<public-ip>

# 7. Tear everything down when you're done — important, this stops billing
terraform destroy
```

`terraform.tfvars` is read automatically — you never pass it with a flag. Any variable not set there falls back to its `default` in `variables.tf`.

### Verifying the block volume on the instance

```bash
lsblk                              # look for an unmounted ~50G device, e.g. sdb
sudo mkfs.xfs /dev/sdb             # format (first time only — destroys data)
sudo mkdir -p /mnt/data
sudo mount /dev/sdb /mnt/data
df -h /mnt/data
```

---

## State and generated files

| Path | Commit to git? | What it is |
|------|----------------|------------|
| `*.tf` | ✅ yes | Your configuration |
| `terraform.tfvars.example` | ✅ yes | Template with placeholder values |
| `.terraform.lock.hcl` | ✅ yes | Exact provider versions, so everyone gets the same ones |
| `terraform.tfvars` | ❌ **no** | Contains your real OCIDs |
| `terraform.tfstate`, `*.tfstate.backup` | ❌ **no** | Records what Terraform built; may contain sensitive values |
| `.terraform/` | ❌ no | Downloaded provider binaries, hundreds of MB |

`terraform.tfstate` is Terraform's map from your config to real cloud resources. **Do not delete or hand-edit it** — without it, Terraform loses track of what it created and `destroy` can no longer clean up.

A [.gitignore](.gitignore) is included and already covers all of the above, plus plan files, override files, and stray key material (`*.pem`, `*.key`, `*.pub`). Note the two deliberate exceptions:

- `*.tfvars` is ignored, but `!terraform.tfvars.example` re-includes the template so it stays in the repo.
- `.terraform/` is ignored while `.terraform.lock.hcl` is **not** — the lock file is a top-level file, not inside that directory, so it is committed as intended.

---

## Notes and known rough edges

- **SSH is open to the world.** The ingress rule uses source `0.0.0.0/0`. Fine for a short-lived lab; for anything longer, narrow it to your own IP (`<your.ip>/32`).
- **Free tier:** `VM.Standard.E5.Flex` is a paid shape. The Always Free shapes are `VM.Standard.E2.1.Micro` (x86) and `VM.Standard.A1.Flex` (Arm, up to 4 OCPU / 24 GB). Free-tier block storage is capped at 200 GB total. Check your usage if you want to stay at zero cost.
- **Availability domain is hardcoded to index `[0]`.** If capacity runs out in that AD ("Out of host capacity"), try `[1]` or `[2]` in [compute.tf](compute.tf) — assuming your region has more than one AD.
- **`dns_label` does not follow `lab_name`.** The VCN and subnet keep `lab1vcntf` / `publicsubtf` because OCI treats those as immutable. Only visible if you inspect the VCN's DNS settings; making them match would require destroying and recreating the whole stack.
- **`terraform.tfvars.example` uses a placeholder OCID.** It is the one tfvars file that *is* committed (`.gitignore` re-includes it), so it deliberately carries `ocid1.compartment.oc1..xxxx…` rather than a real value. Your real one lives in `terraform.tfvars`.

---

## Troubleshooting

| Error | Cause / fix |
|-------|-------------|
| `NotAuthenticated` / `401` | `~/.oci/config` is missing, has the wrong fingerprint, or points at a `key_file` that doesn't exist |
| `NotAuthorizedOrNotFound` | Wrong `compartment_id`, or your user lacks IAM policy in that compartment |
| `Out of host capacity` | The shape isn't available in that AD right now — change AD index or shape |
| `no suitable image found` / empty `images[0]` | The image lookup returned nothing; the OS version and `vm_shape` combination may not exist in your region |
| `Invalid function argument` on `file(...)` | `ssh_pubkey_file` points at a file that isn't there. Use forward slashes on Windows: `C:/path/key.pub` |
| Plan wants to destroy everything after a rename | A `moved` block is missing for the renamed resource — see [moved.tf](moved.tf) |
| Instance created but SSH times out | Check the security list ingress rule, that the subnet has `prohibit_public_ip_on_vnic = false`, and that you're using the **private** key with `ssh -i` |

---

## Cost reminder

Compute instances and block volumes bill for as long as they exist, whether or not you use them. When the lab is finished:

```bash
terraform destroy
```
