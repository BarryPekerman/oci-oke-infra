# Public sites served by this cluster, through Cloudflare. They live here, with
# the cluster, so they don't depend on The Handover's infra (handover-hosting).
#
# The personal site (oke-gitops portfolio/) at barrypekerman.com. A cloudflared
# deployment in the cluster runs this tunnel to the site's service, so nothing
# in the cluster is exposed. Public: no Access in front. The run token goes into
# oke-gitops as the SOPS secret portfolio/tunnel.enc.yaml (from the output below).
#
# www is the test hostname: it goes live first, while the bare domain still
# redirects to the game (handover-hosting/infra/apex.tf). Deleting apex.tf and
# adding the apex record here is the switch-over.
locals {
  cf_account = "dbcba7623c52bc78632ae5f31399a06d"
  cf_zone    = "8e1c1adb257eb08052cc949c2ae7bb0c" # barrypekerman.com
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "portfolio" {
  account_id = local.cf_account
  name       = "oke-portfolio"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "portfolio" {
  account_id = local.cf_account
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.portfolio.id
  config = {
    ingress = [
      { hostname = "barrypekerman.com", service = "http://portfolio.portfolio.svc.cluster.local:80" },
      { hostname = "www.barrypekerman.com", service = "http://portfolio.portfolio.svc.cluster.local:80" },
      { service = "http_status:404" },
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "portfolio" {
  account_id = local.cf_account
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.portfolio.id
}

resource "cloudflare_dns_record" "portfolio_www" {
  zone_id                 = local.cf_zone
  name                    = "www.barrypekerman.com"
  type                    = "CNAME"
  content                 = "${cloudflare_zero_trust_tunnel_cloudflared.portfolio.id}.cfargotunnel.com"
  proxied                 = true
  ttl                     = 1
  tags                    = []
  include_shadow_metadata = false
  settings = {
    flatten_cname = false
    ipv4_only     = false
    ipv6_only     = false
  }
}

output "portfolio_tunnel_token" {
  description = "cloudflared run token for the cluster's portfolio tunnel"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.portfolio.token
  sensitive   = true
}
