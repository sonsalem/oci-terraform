# Week 3 Lab — Terraform Modules + OKE (VCN-native pods) + App on Block Volume behind a Load Balancer

This project implements everything asked for in the Week 3 assignment:

- **Subnet module** (`modules/subnet`) — 4 resources: Subnet, Route Table, Security List, and a
  conditional "Enable Logs" (VCN Flow Log).
- **OKE module** (`modules/oke`) — creates the OKE cluster and a **managed worker node pool with
  VCN-native pod networking** (`OCI_VCN_IP_NATIVE`).
- Both modules are **generic and reusable**: nothing is hardcoded, every value is a variable, and
  the root configuration (`main.tf` / `terraform.tfvars`) supplies real values. They use **dynamic
  blocks** (route rules, security rules, placement configs, pod-network options, flex shape
  config) and **conditional expressions** (`count`, ternaries, `for_each` on empty/one-element
  lists) throughout, exactly as the assignment asked you to research.
- `k8s/` — a demo app Deployment, a PersistentVolumeClaim backed by an OCI Block Volume, and a
  Service of `type: LoadBalancer` to expose it.

**Status: applied and verified end to end** in `me-jeddah-1` — an OKE cluster running Kubernetes
v1.36.1 with a 3-node managed pool, pods getting real VCN IPs from the pod subnet, a 50Gi block
volume attached to the app, and the app reachable over a public OCI Load Balancer. The actual
command output is in [Verification](#verification) below.

## Project layout

```
week3/
├── main.tf                    # root: VCN, gateways, calls both modules
├── variables.tf               # root inputs
├── outputs.tf
├── providers.tf
├── terraform.tfvars.example   # copy to terraform.tfvars and fill in
├── modules/
│   ├── subnet/                # reusable Subnet module (4 resources)
│   └── oke/                   # reusable OKE module (cluster + node pool)
└── k8s/
    ├── 00-namespace.yaml
    ├── 10-storageclass.yaml
    ├── 20-pvc.yaml            # external block volume claim
    ├── 30-deployment.yaml     # app, mounts the block volume
    └── 40-service.yaml        # LoadBalancer
```

## 1. Prerequisites

- An OCI account + a compartment you can create resources in.
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm) (used to fetch kubeconfig)
- `kubectl`
- An API signing key configured for the OCI provider — see
  [Required Keys and OCIDs](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm).
  Credentials are read from `~/.oci/config` (profile chosen by `oci_config_profile`), so no OCIDs,
  fingerprints or key paths are duplicated into this repo.

## 2. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
# then edit terraform.tfvars with your own OCIDs / region / compartment
```

`terraform.tfvars` is git-ignored — never commit it, it can contain sensitive values.

## 3. Provision the infrastructure

```bash
terraform init
terraform plan   # review carefully before applying — this creates billable resources
terraform apply
```

This creates: VCN + Internet/NAT/Service gateways → 4 subnets (endpoint / workers / pods / LB),
each with its own route table + security list, and optional VCN Flow Logs → an OKE cluster → a
managed node pool with VCN-native pod networking.

## 4. Connect kubectl to the new cluster

Terraform prints the exact command as an output:

```bash
terraform output -raw get_kubeconfig_command
# then run the printed command, e.g.:
oci ce cluster create-kubeconfig \
  --cluster-id $(terraform output -raw cluster_id) \
  --file $HOME/.kube/config \
  --region <your-region> \
  --token-version 2.0.0

kubectl get nodes -o wide   # wait until the worker nodes show Ready
```

## 5. Deploy the application, block volume, and Load Balancer

```bash
kubectl apply -f k8s/
```

`kubectl apply -f <dir>` processes the files in alphabetical order, which is why the manifests are
numbered: the Namespace has to exist before the Deployment lands in it, otherwise the apply fails
with `namespaces "week3-lab" not found`. The prefixes make one command enough. To apply them one
at a time, keep the same order:

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/10-storageclass.yaml
kubectl apply -f k8s/20-pvc.yaml
kubectl apply -f k8s/30-deployment.yaml
kubectl apply -f k8s/40-service.yaml
```

Then watch it come up:

```bash
kubectl -n week3-lab get pvc                  # wait until it's Bound
kubectl -n week3-lab get pods -o wide         # wait until Running; the pod IP must be
                                              # inside the pod subnet CIDR (VCN-native!)
kubectl -n week3-lab get svc week3-app-lb -w  # wait for EXTERNAL-IP to be assigned
```

## Verification

Recorded from the live cluster after `terraform apply` plus the manifests above.

**Worker nodes — private IPs from the worker subnet (`10.0.1.0/24`):**

```
$ kubectl get nodes
NAME         STATUS   ROLES   AGE     VERSION
10.0.1.115   Ready    node    4h38m   v1.36.1
10.0.1.134   Ready    node    4h37m   v1.36.1
10.0.1.235   Ready    node    4h38m   v1.36.1
```

**VCN-native pod networking — the pod IP comes from the dedicated pod subnet (`10.0.16.0/20`),
not from an overlay range:**

```
$ kubectl get pods -n week3-lab -o wide
NAME                        READY   STATUS    RESTARTS   AGE     IP            NODE
week3-app-cc4cc47bb-np87z   1/1     Running   0          2m15s   10.0.17.148   10.0.1.134
```

**External block volume — provisioned by the OCI Block Volume CSI driver and bound to the app:**

```
$ kubectl get pvc -n week3-lab
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
app-data-pvc   Bound    csi-e2ed3922-a2b6-4807-907a-7b844b8490eb   50Gi       RWO            oci-bv-balanced
```

**Load Balancer — OCI provisioned a public LB for the `type: LoadBalancer` Service:**

```
$ kubectl get svc -n week3-lab
NAME           TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)        AGE
week3-app-lb   LoadBalancer   10.96.175.83   193.122.88.0   80:31653/TCP   2m43s

$ curl 193.122.88.0
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 615

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

**The volume really is external storage, not node-local** — write a file, delete the pod, and the
file is still there on the replacement pod, because the CSI driver re-attached the same block
volume to it:

```
$ kubectl exec -n week3-lab deploy/week3-app -- sh -c "echo 'OCI Block Volume test' > /usr/share/nginx/html/data/test.txt"
$ kubectl exec -n week3-lab deploy/week3-app -- cat /usr/share/nginx/html/data/test.txt
OCI Block Volume test

$ kubectl delete pod -n week3-lab -l app=week3-app
pod "week3-app-cc4cc47bb-np87z" deleted from week3-lab namespace

$ kubectl get pods -n week3-lab
NAME                        READY   STATUS    RESTARTS   AGE
week3-app-cc4cc47bb-h6glr   1/1     Running   0          36s

$ kubectl exec -n week3-lab deploy/week3-app -- cat /usr/share/nginx/html/data/test.txt
OCI Block Volume test
```

## 6. Tear down

```bash
kubectl delete -f k8s/40-service.yaml -f k8s/30-deployment.yaml -f k8s/20-pvc.yaml -f k8s/10-storageclass.yaml -f k8s/00-namespace.yaml
terraform destroy
```

Delete the Kubernetes Service **before** `terraform destroy` — otherwise the OCI Load Balancer it
provisioned is orphaned outside of Terraform's state and you'll have to remove it manually from
the Console. The same applies to the PVC: deleting it releases the 50Gi block volume, which is
billed for as long as it exists.

## Where the assignment's specific concepts show up

| Concept | Where |
|---|---|
| Dynamic blocks | `modules/subnet/main.tf` (route_rules, ingress/egress rules, tcp/udp_options); `modules/oke/main.tf` (placement_configs, node_pool_pod_network_option_details, node_shape_config) |
| Conditional expressions | `enable_flow_logs ? 1 : 0` (subnet flow log), `cni_type == "OCI_VCN_IP_NATIVE" ? [1] : []` (pod network block), `length(regexall("Flex", var.node_shape)) > 0 ? [1] : []` (flex shape sizing), `pods_cidr = var.cni_type == "FLANNEL_OVERLAY" ? var.pods_cidr : null` |
| Reusable/configurable modules | Every value in `modules/subnet` and `modules/oke` comes from a variable — no hardcoded OCIDs, CIDRs, or names anywhere in module code |
| VCN-native pod networking | `pod_subnet_id` + `node_pool_pod_network_option_details { cni_type = "OCI_VCN_IP_NATIVE" }` in `modules/oke/main.tf`, backed by the dedicated `pod_subnet` (a /20) created in root `main.tf` — proven by the `10.0.17.148` pod IP above |
| Managed node pool | `oci_containerengine_node_pool` in `modules/oke/main.tf` |
| External block volume attached to the app | `k8s/20-pvc.yaml` (StorageClass `oci-bv-balanced`, backed by the OCI Block Volume CSI driver) mounted in `k8s/30-deployment.yaml` |
| Load Balancer exposure | `k8s/40-service.yaml`, `type: LoadBalancer`, backed by the dedicated `lb_subnet` |

## A note on security lists

The ingress/egress rules included are intentionally permissive *within the VCN* to keep the lab
focused on the Terraform/OKE mechanics — before treating this as production-ready, tighten them
per Oracle's [OKE network security list requirements](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengnetworkconfig.htm)
(restrict worker↔control-plane traffic to the specific ports OKE needs, remove the wide-open
`source = var.vcn_cidr_block` "allow all" rules, etc.). The module already supports this — just
pass a tighter `ingress_rules` / `egress_rules` list from the root config, no module code changes
needed.
