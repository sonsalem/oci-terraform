# OCI Terraform Labs

Weekly Terraform labs for an Oracle Cloud Infrastructure course.

Each week is a **self-contained Terraform root module**: its own `provider.tf`, variables, state file, and provider lock. You `init`, `apply`, and `destroy` one week without touching the others, and a broken week never takes the rest down with it.

> The repository is named `oci-terraform-week1` for historical reasons — it holds every week, not just the first.

## Weeks

| Week | Folder | What it builds | Status |
|------|--------|----------------|--------|
| 1 | [week1/](week1/) | VCN with internet access, one Oracle Linux 9 instance over SSH, 50 GB block volume attached | Complete |
| 2 | [week2/](week2/) | VCN with public + private subnets, Application Load Balancer in front of a private instance, app files on File Storage over NFS | Complete |
| 3 | — | — | Not added yet |
| 4 | — | — | Not added yet |

Weeks 3 and 4 have no folder in the repo yet. When they land, they follow the same layout: one directory, one root module, one README.

## Shared setup

Do this once — it applies to every week.

1. **Terraform ≥ 1.3.0** (labs tested with v1.15.8 and OCI provider v7.32.0)
2. **An OCI account** with permission to create networking and compute in your target compartment
3. **`~/.oci/config`** with a `DEFAULT` profile:
   ```ini
   [DEFAULT]
   user=ocid1.user.oc1..xxxx
   fingerprint=aa:bb:cc:...
   key_file=C:/path/to/your_api_private_key.pem
   tenancy=ocid1.tenancy.oc1..xxxx
   region=me-jeddah-1
   ```
   Generate it from the OCI Console: Profile → My profile → API keys → Add API key.
4. **An SSH key pair for the VMs**, separate from the API key above:
   ```bash
   ssh-keygen -t rsa -b 4096 -f C:/salem-oci/oci-lab-key
   ```

Credentials live in `~/.oci/config`, never in this repo. No OCIDs or key material appear in any `.tf` file.

## Running any week

```bash
cd week1                              # or week2, ...
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: compartment OCID + public key path

terraform init
terraform validate
terraform fmt
terraform plan
terraform apply

terraform output ssh_connection_command

terraform destroy                     # stops billing
```

Every week reads its own `terraform.tfvars` automatically. Anything you leave unset falls back to the default in that week's `variables.tf`.

**Run `terraform destroy` when you finish a lab.** The default shape is a paid one; an instance left running bills by the hour.

## Repository layout

```
oci-terraform-week1/
├── README.md                    # this file
├── .gitignore                   # covers every week
├── week1/
│   ├── README.md                # week 1 walkthrough
│   ├── provider.tf              # Terraform + OCI provider setup
│   ├── variables.tf             # input variables
│   ├── network.tf               # VCN, IGW, route table, security list, subnet
│   ├── compute.tf               # data lookups, instance, block volume, attachment
│   ├── outputs.tf               # values printed after apply
│   ├── moved.tf                 # rename history, deletable after apply
│   ├── terraform.tfvars.example # template
│   ├── terraform.tfvars         # real values (gitignored)
│   └── .terraform.lock.hcl      # locked provider versions (committed)
└── week2/
    ├── README.md                # week 2 walkthrough
    ├── provider.tf              # same idea, split further as the stack grew
    ├── variables.tf
    ├── locals.tf                # names, constants, derived values
    ├── data.tf                  # AD, image and mount-target IP lookups
    ├── network.tf               # VCN, gateways, route tables, security lists, subnets
    ├── compute.tf               # the private application instance
    ├── fss.tf                   # File Storage: file system, mount target, export
    ├── loadbalancer.tf          # load balancer, backend set, backend, listener
    ├── outputs.tf
    ├── templates/               # cloud-init first-boot script
    ├── docs/                    # architecture diagram + screenshots
    └── ...
```

The `.gitignore` sits at the root and applies to every week, so a new week folder is protected the moment you create it.

## Why one root module per week

State is per-directory. Keeping the weeks separate means:

- Week 2's `apply` can't clobber resources week 1 is tracking.
- You can destroy an old week and keep a newer one running.
- Each week pins its own provider version in `.terraform.lock.hcl`.

The cost is duplication — shared code is copied, not factored into a module. That's deliberate for a teaching repo: each week reads top to bottom on its own.

## What not to commit

| Pattern | Why |
|---------|-----|
| `terraform.tfvars` | Your real compartment OCID and key paths |
| `*.tfstate`, `*.tfstate.*` | Records what exists in your cloud account; can hold secrets in plaintext |
| `.terraform/` | Downloaded provider binaries, hundreds of MB, recreated by `terraform init` |
| `*.tfplan` | A saved plan can embed sensitive variable values |
| `*.pem`, `*.key`, `*.pub`, `id_rsa*` | Key material |

The root `.gitignore` covers all of these. `terraform.tfvars.example` is safe and committed — the `*.tfvars` rule doesn't match it, since the filename ends in `.example`.

`.terraform.lock.hcl` **is** committed on purpose, so everyone resolves the same provider versions.

Don't delete or hand-edit a `terraform.tfstate`. Without it Terraform loses track of what it built, and `destroy` can no longer clean up — you'd be deleting resources by hand in the Console.
