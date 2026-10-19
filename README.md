# OKE Free Tier Dev Environment

Terraform for an Oracle Cloud Always Free OKE cluster, plus the ArgoCD install
that the workloads are deployed through. Besides a wiki, the cluster runs the
monitoring for [The Handover](https://play.barrypekerman.com), a browser-based
Linux & DevOps wargame hosted in a separate OCI tenancy
([handover-hosting](https://github.com/BarryPekerman/handover-hosting)).

## Architecture

```
OCI Always Free (il-jerusalem-1)
├── OKE Basic Cluster (managed control plane, free)
│   └── Node Pool: 2x VM.Standard.A1.Flex (2 OCPU, 12GB RAM each)
├── VCN (public + private subnets)
└── Block Storage (200GB budget: 2x50GB boot + PVCs)

Kubernetes Workloads
├── ArgoCD         (Helm, values in kubernetes/argocd/ — ksops sidecar for SOPS secrets)
└── via ArgoCD, managed in the oke-gitops repo (app-of-apps):
    ├── wiki           (MediaWiki, 50GB PVC on oci-bv-free-tier)
    ├── cert-manager
    ├── envoy-gateway  (public ingress)
    └── monitoring     (kube-prometheus-stack: Prometheus with 60 days on a node-local
                        volume, Alertmanager to Telegram, Grafana behind Cloudflare
                        Access; scrapes The Handover's game host through its tunnel)
```

## Free Tier Budget

| Resource | Limit | Used |
|---|---|---|
| OKE Cluster | 1 Basic | 1 |
| Compute | 4 OCPU, 24GB | 4 OCPU, 24GB (2x2 / 2x12) |
| Block Storage | 200GB | 100GB boot + 50GB wiki PVC |
| Volume Backups | 5 | ≤ 3 (2 weekly + 1 pre-upgrade); check with `scripts/check-free-tier.sh` |
| Outbound Data | 10TB/mo | Minimal |

## Terraform

**State** lives in HCP Terraform (org `Berries-`, workspace `oci-oke-infra`) in
**Local** execution mode: plans and applies run on your machine, HCP only stores
and locks the state. **Auth** comes from the OCI CLI config (`~/.oci/config`,
profile `DEFAULT`), so no API key sits in a tfvars file. CI
(`.github/workflows/terraform-check.yml`) runs `fmt` + `validate` only and never
plans or applies.

```bash
terraform login                       # once per machine
cd terraform
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars   # fill in
terraform init
terraform plan  -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

The state was rebuilt on 2026-10-17 with `import` blocks after the original
local state file was left on another machine: 31 resources imported, then
`plan` showed no changes.

The cluster/node-pool Kubernetes version and node image are **owned by
[oke-version-guard](https://github.com/BarryPekerman/oke-version-guard)** after
creation (`lifecycle.ignore_changes`), so Terraform never fights its upgrades.

### Volume backups
`modules/backups` holds one weekly policy (`pvc-weekly-dev`: FULL, Sunday 03:00
UTC, kept 10 days) and assigns it to the PVC volumes listed in
`backup_volume_ids`. The volumes themselves belong to Kubernetes (the CSI driver
creates them for PVCs); only the schedule is managed here. At most 2 weekly
backups exist, plus the one pre-upgrade backup oke-version-guard keeps per
volume; Always Free allows 5.

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
  modules/backups/      # Weekly backup policy for PVC volumes
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
