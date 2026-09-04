# OKE Free Tier Dev Environment

Maximal Oracle Cloud Always Free tier Kubernetes environment with GitOps.

## Architecture

```
OCI Always Free (il-jerusalem-1)
├── OKE Basic Cluster (managed control plane, free)
│   └── Node Pool: 1x VM.Standard.A1.Flex (4 OCPU, 24GB RAM)
├── VCN (public + private subnets)
├── Block Storage (200GB budget: 50GB boot + 150GB PVCs)
└── Cloudflare Tunnel (secure public ingress, no LB needed)

Kubernetes Workloads
├── ArgoCD          (GitOps - Helm)
├── cloudflared     (Cloudflare Tunnel)
├── PostgreSQL      (Bitnami Helm, 20GB PVC)
├── n8n             (workflow automation, 10GB PVC)
└── Free Tier Monitor (CronJob, usage alerts)
```

## Free Tier Budget

| Resource | Limit | Used |
|---|---|---|
| OKE Cluster | 1 Basic | 1 |
| Compute | 4 OCPU, 24GB | 4 OCPU, 24GB |
| Block Storage | 200GB | 50GB boot + PVCs |
| Load Balancer | 1 flexible | 0 (Cloudflare Tunnel) |
| Outbound Data | 10TB/mo | Minimal |

## Quick Start

```bash
# 1. Deploy infrastructure
cd terraform
terraform init
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars

# 2. Configure kubectl
./scripts/setup-kubeconfig.sh

# 3. Deploy everything
./scripts/deploy.sh
```

## Project Structure

```
terraform/              # OKE infrastructure (Terraform)
  modules/networking/   # VCN, subnets, gateways, NSGs
  modules/oke/          # OKE cluster + ARM64 node pool
  modules/iam/          # Dynamic groups + policies
kubernetes/             # Kubernetes manifests
  argocd/               # ArgoCD Helm values
  cloudflared/          # Cloudflare Tunnel deployment
  apps/postgresql/      # PostgreSQL (Wave 2)
  apps/n8n/             # n8n (Wave 2)
  monitoring/           # StorageClass + free tier monitor
scripts/                # Deployment and utility scripts
.github/workflows/      # CI/CD pipeline
v1-k3s/                 # Archived K3s-era files
```

## Deployment Waves

**Wave 1 (GitOps Foundation):**
- OKE cluster via Terraform
- Cloudflare Tunnel for ingress
- ArgoCD for GitOps

**Wave 2 (Applications, ArgoCD-managed):**
- PostgreSQL (shared database)
- n8n (workflow automation)
- Additional stateful apps

## Scripts

| Script | Purpose |
|---|---|
| `scripts/deploy.sh` | Full end-to-end deployment |
| `scripts/setup-kubeconfig.sh` | Generate kubectl config |
| `scripts/check-free-tier.sh` | Check OCI usage vs limits |

## Cloudflare Tunnel Setup

1. Create a Cloudflare account and add your domain
2. Create a tunnel: `cloudflared tunnel create oke-free`
3. Create `kubernetes/cloudflared/secret.yaml` from the example
4. Update `kubernetes/cloudflared/configmap.yaml` with tunnel ID and domain
5. Deploy: `kubectl apply -f kubernetes/cloudflared/`
