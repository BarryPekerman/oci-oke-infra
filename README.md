# OKE Free Tier Dev Environment

Terraform for an Oracle Cloud Always Free OKE cluster, plus the ArgoCD install
that the workloads are deployed through.

## Architecture

```
OCI Always Free (il-jerusalem-1)
├── OKE Basic Cluster (managed control plane, free)
│   └── Node Pool: 2x VM.Standard.A1.Flex (2 OCPU, 12GB RAM each)
├── VCN (public + private subnets)
└── Block Storage (200GB budget: 2x50GB boot + PVCs)

Kubernetes Workloads
├── ArgoCD         (Helm, values in kubernetes/argocd/ — ksops sidecar for SOPS secrets)
└── via ArgoCD, managed in the migrate-schitzopunk repo:
    ├── wiki           (MediaWiki, 50GB PVC on oci-bv-free-tier)
    ├── cert-manager
    └── envoy-gateway  (public ingress)
```

## Free Tier Budget

| Resource | Limit | Used |
|---|---|---|
| OKE Cluster | 1 Basic | 1 |
| Compute | 4 OCPU, 24GB | 4 OCPU, 24GB (2x2 / 2x12) |
| Block Storage | 200GB | 100GB boot + 50GB wiki PVC |
| Volume Backups | 5 | check with `scripts/check-free-tier.sh` |
| Outbound Data | 10TB/mo | Minimal |

## Terraform

State is **not** in this repo — apply only from the machine that holds
`terraform/terraform.tfstate`. CI (`.github/workflows/terraform-check.yml`) runs
`fmt` + `validate` only and never plans or applies.

```bash
cd terraform
terraform init
terraform plan  -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

The cluster/node-pool Kubernetes version and node image are **owned by
[oke-version-guard](https://github.com/BarryPekerman/oke-version-guard)** after
creation (`lifecycle.ignore_changes`), so Terraform never fights its upgrades.

### CI upgrader identity
`modules/ci-upgrader` creates the scoped user + group + policy that
oke-version-guard authenticates as. Opt-in via `enable_ci_upgrader`; apply it on
its own:
```bash
terraform apply -var-file=environments/dev/terraform.tfvars -target=module.ci_upgrader
```

## Project Structure

```
terraform/              # OKE infrastructure (Terraform)
  modules/networking/   # VCN, subnets, gateways, NSGs
  modules/oke/          # OKE cluster + ARM64 node pool
  modules/iam/          # Dynamic group + node policies (block volumes for PVCs)
  modules/ci-upgrader/  # Scoped CI identity for oke-version-guard
kubernetes/
  argocd/               # ArgoCD Helm values
  storage/              # oci-bv-free-tier StorageClass (used by the wiki PVC)
scripts/                # Deployment and utility scripts
.github/workflows/      # Terraform static checks
```

## Scripts

| Script | Purpose |
|---|---|
| `scripts/deploy.sh` | Terraform apply → kubeconfig → StorageClass → ArgoCD |
| `scripts/setup-kubeconfig.sh` | Generate kubectl config |
| `scripts/check-free-tier.sh` | Check OCI usage vs Always Free limits |
