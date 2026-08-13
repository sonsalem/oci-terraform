# OCI Terraform — Week 1 Lab

First week of the lab series — see the [repository root](../README.md) for the other weeks and the one-time setup.

Terraform config for a small lab environment in Oracle Cloud Infrastructure: a VCN with internet access, one Oracle Linux 9 instance reachable over SSH, and a block volume attached to it.

One `terraform apply` builds it, one `terraform destroy` removes it.

## What gets created

| Resource | Terraform address | Notes |
|----------|-------------------|-------|
| VCN | `oci_core_vcn.lab_vcn` | `10.0.0.0/16` |
| Internet Gateway | `oci_core_internet_gateway.lab_igw` | |
| Route Table | `oci_core_route_table.lab_route_table` | `0.0.0.0/0` → IGW |
| Security List | `oci_core_security_list.lab_security_list` | inbound TCP 22, all outbound |
| Public Subnet | `oci_core_subnet.lab_public_subnet` | `10.0.0.0/24`, public IPs allowed |
| Compute Instance | `oci_core_instance.lab_instance` | Oracle Linux 9, `VM.Standard.E5.Flex`, 1 OCPU / 12 GB |
| Block Volume | `oci_core_volume.lab_block_volume` | 50 GB |
| Volume Attachment | `oci_core_volume_attachment.lab_volume_attachment` | paravirtualized |

Display names are `"${var.lab_name}-<role>"`, so renaming the lab is a one-line change.

Two data sources look things up without creating anything: `oci_identity_availability_domains` for the region's ADs, and `oci_core_images` for the newest Oracle Linux 9 image matching the shape.

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

## File structure

```
week1/
├── provider.tf                 # Terraform + OCI provider setup
├── variables.tf                # Input variables
├── network.tf                  # VCN, IGW, route table, security list, subnet
├── compute.tf                  # Data lookups, instance, block volume, attachment
├── outputs.tf                  # Values printed after apply
├── moved.tf                    # Rename history, deletable after apply
├── terraform.tfvars            # Real values (gitignored)
├── terraform.tfvars.example    # Template
├── terraform.tfstate           # Local state (gitignored)
└── .terraform.lock.hcl         # Locked provider versions (commit this)
```

The `.gitignore` lives at the [repository root](../README.md) and covers every week.

## Variables

| Variable | Default | Notes |
|----------|---------|-------|
| `lab_name` | `salem-lab` | Prefix for display names |
| `oci_region` | `me-jeddah-1` | |
| `compartment_id` | *(required)* | No default on purpose, it's tenancy-specific |
| `ssh_pubkey_file` | `C:/salem-oci/ssh-key-2026-08-07.key.pub` | Path to the **public** key |
| `vcn_cidr` | `10.0.0.0/16` | |
| `subnet_cidr` | `10.0.0.0/24` | Must sit inside the VCN range |
| `vm_shape` | `VM.Standard.E5.Flex` | |
| `vm_ocpus` | `1` | |
| `vm_memory_gb` | `12` | |
| `volume_size_gb` | `50` | OCI minimum is 50 |

Credentials come from `~/.oci/config` (profile `DEFAULT`), not from this repo. No keys or OCIDs live in the Terraform code.

`dns_label` on the VCN and subnet stays at `lab1vcntf` / `publicsubtf` rather than following `lab_name`. OCI treats it as immutable, so changing it would rebuild the whole stack.

## Prerequisites

1. Terraform ≥ 1.3.0 (tested with v1.15.8 / OCI provider v7.32.0)
2. An OCI account with permission to create networking and compute in the target compartment
3. `~/.oci/config` with a `DEFAULT` profile:
   ```ini
   [DEFAULT]
   user=ocid1.user.oc1..xxxx
   fingerprint=aa:bb:cc:...
   key_file=C:/path/to/your_api_private_key.pem
   tenancy=ocid1.tenancy.oc1..xxxx
   region=me-jeddah-1
   ```
   Get it from the OCI Console: Profile → My profile → API keys → Add API key.
4. An SSH key pair for the VM (separate from the API key):
   ```bash
   ssh-keygen -t rsa -b 4096 -f C:/salem-oci/oci-lab-key
   ```

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit it: compartment OCID + public key path

terraform init
terraform validate
terraform fmt
terraform plan
terraform apply

terraform output ssh_connection_command
ssh -i C:/salem-oci/oci-lab-key opc@<public-ip>

terraform destroy    # stops billing
```

`terraform.tfvars` is picked up automatically. Anything not set there falls back to the default in `variables.tf`.

### Mounting the block volume

```bash
lsblk                              # look for an unmounted ~50G device, e.g. sdb
sudo mkfs.xfs /dev/sdb             # first time only, destroys data
sudo mkdir -p /mnt/data
sudo mount /dev/sdb /mnt/data
df -h /mnt/data
```

## What not to commit

`terraform.tfvars` (real OCIDs), `*.tfstate` and backups (may contain sensitive values), and `.terraform/` (provider binaries). The root `.gitignore` covers these, plus plan files and stray key material. `terraform.tfvars.example` is safe and committed — the `*.tfvars` rule doesn't match it, since the filename ends in `.example`. `.terraform.lock.hcl` is committed on purpose, so everyone gets the same provider versions.

Don't delete or hand-edit `terraform.tfstate` — without it Terraform loses track of what it built and `destroy` can't clean up.

## Rough edges

- SSH is open to `0.0.0.0/0`. Fine for a short-lived lab, narrow it to `<your.ip>/32` for anything longer.
- `VM.Standard.E5.Flex` is a paid shape. Always Free options are `VM.Standard.E2.1.Micro` and `VM.Standard.A1.Flex`; free block storage caps at 200 GB.
- The availability domain is hardcoded to index `[0]`. On "Out of host capacity", try `[1]` or `[2]` in [compute.tf](compute.tf).

## Troubleshooting

| Error | Cause |
|-------|-------|
| `NotAuthenticated` / `401` | `~/.oci/config` missing, wrong fingerprint, or bad `key_file` path |
| `NotAuthorizedOrNotFound` | Wrong `compartment_id`, or no IAM policy in that compartment |
| `Out of host capacity` | Shape unavailable in that AD, change the AD index or shape |
| `Invalid function argument` on `file(...)` | `ssh_pubkey_file` path is wrong. Use forward slashes on Windows |
| Plan wants to destroy everything after a rename | Missing `moved` block, see [moved.tf](moved.tf) |
| SSH times out | Check the ingress rule, `prohibit_public_ip_on_vnic = false`, and that you're using the private key with `ssh -i` |
