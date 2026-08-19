# OCI Terraform Labs

Weekly Terraform labs for an Oracle Cloud Infrastructure course.

Each week is a **self-contained Terraform root module**: its own provider config, variables, state file, and provider lock. You `init`, `apply`, and `destroy` one week without touching the others, and a broken week never takes the rest down with it.

Weeks 1 and 2 are flat — every resource sits in the root. Week 3 introduces **child modules** under `week3/modules/`, since the assignment asked for reusable ones.

> The repository is named `oci-terraform-week1` for historical reasons — it holds every week, not just the first.

## Weeks

| Week | Folder | What it builds | Status |
|------|--------|----------------|--------|
| 1 | [week1/](week1/) | VCN with internet access, one Oracle Linux 9 instance over SSH, 50 GB block volume attached | Complete |
| 2 | [week2/](week2/) | VCN with public + private subnets, Application Load Balancer in front of a private instance, app files on File Storage over NFS | Complete |
| 3 | [week3/](week3/) | OKE cluster with VCN-native pod networking, 3-node managed pool, nginx on a block-volume PVC behind a Kubernetes-provisioned load balancer | Complete |
| 4 | — | — | Not added yet |

Week 4 has no folder yet. When it lands it follows the same layout: one directory, one root module, one README.

## Shared setup

Do this once — it applies to every week.

1. **Terraform ≥ 1.3.0** — week 3 needs **≥ 1.5.0** (labs tested with v1.15.8, OCI provider v7.32.0 for weeks 1–2 and v8.23.0 for week 3)
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

Week 3 also needs the **OCI CLI** and **kubectl** — Terraform builds the cluster, but you fetch the kubeconfig and deploy the app yourself.

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

terraform output                      # week-specific: SSH command, app URL, kubeconfig command

terraform destroy                     # stops billing
```

Every week reads its own `terraform.tfvars` automatically. Anything you leave unset falls back to the default in that week's `variables.tf`.

Week 3 doesn't finish at `apply` — the cluster comes up empty. Fetch the kubeconfig with the printed `get_kubeconfig_command`, then apply `week3/k8s/` in filename order to get the app running. Delete the Kubernetes Service **before** `terraform destroy`, or the load balancer it created outlives the state file and has to be removed by hand.

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
├── week2/
│   ├── README.md                # week 2 walkthrough
│   ├── provider.tf              # same idea, split further as the stack grew
│   ├── variables.tf
│   ├── locals.tf                # names, constants, derived values
│   ├── data.tf                  # AD, image and mount-target IP lookups
│   ├── network.tf               # VCN, gateways, route tables, security lists, subnets
│   ├── compute.tf               # the private application instance
│   ├── fss.tf                   # File Storage: file system, mount target, export
│   ├── loadbalancer.tf          # load balancer, backend set, backend, listener
│   ├── outputs.tf
│   ├── templates/               # cloud-init first-boot script
│   ├── docs/                    # architecture diagram + screenshots
│   └── ...
└── week3/
    ├── README.md                # week 3 walkthrough
    ├── providers.tf             # note the plural — same job as provider.tf above
    ├── variables.tf
    ├── main.tf                  # VCN, gateways, log group, then calls both modules
    ├── outputs.tf
    ├── modules/
    │   ├── subnet/              # route table + security list + subnet + flow log
    │   └── oke/                 # cluster + managed node pool
    └── k8s/                     # namespace, storage class, PVC, deployment, service
```

The `.gitignore` sits at the root and applies to every week, so a new week folder is protected the moment you create it.

## Why one root module per week

State is per-directory. Keeping the weeks separate means:

- Week 2's `apply` can't clobber resources week 1 is tracking.
- You can destroy an old week and keep a newer one running.
- Each week pins its own provider version in `.terraform.lock.hcl`.

The cost is duplication — shared code is copied, not factored into a module. That's deliberate for a teaching repo: each week reads top to bottom on its own. Week 3's modules are reused *within* week 3 (the subnet module runs four times), not shared across weeks.

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
