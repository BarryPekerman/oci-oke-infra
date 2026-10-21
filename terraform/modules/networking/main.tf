# ============================================================================
# Networking Module - OKE Free Tier
# VCN, Subnets, Gateways, Route Tables, NSGs
# ============================================================================

# --- VCN ---
resource "oci_core_vcn" "oke_vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "oke-vcn-${var.environment}"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = "okevn${var.environment}"

  freeform_tags = {
    "managed_by"  = "terraform"
    "environment" = var.environment
  }
}

# --- Internet Gateway (public subnet outbound) ---
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-igw-${var.environment}"
  enabled        = true
}

# --- NAT Gateway (private subnet outbound) ---
resource "oci_core_nat_gateway" "natgw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-natgw-${var.environment}"
}

# --- Service Gateway (OCI services access from private subnet) ---
data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_service_gateway" "svcgw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-svcgw-${var.environment}"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
}

# --- Route Tables ---

# Public subnet route table (-> Internet Gateway)
resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-public-rt-${var.environment}"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Private subnet route table (-> NAT + Service Gateway)
resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-private-rt-${var.environment}"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.natgw.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.svcgw.id
  }
}

# --- Subnets ---

# Public subnet for OKE API endpoint and Load Balancers
resource "oci_core_subnet" "public_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.oke_vcn.id
  display_name               = "oke-public-subnet-${var.environment}"
  cidr_block                 = var.public_subnet_cidr
  dns_label                  = "okepub${var.environment}"
  route_table_id             = oci_core_route_table.public_rt.id
  prohibit_public_ip_on_vnic = false
  security_list_ids          = [oci_core_vcn.oke_vcn.default_security_list_id]
}

# Private subnet for OKE worker nodes
resource "oci_core_subnet" "private_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.oke_vcn.id
  display_name               = "oke-private-subnet-${var.environment}"
  cidr_block                 = var.private_subnet_cidr
  dns_label                  = "okeprv${var.environment}"
  route_table_id             = oci_core_route_table.private_rt.id
  prohibit_public_ip_on_vnic = true
  security_list_ids          = [oci_core_vcn.oke_vcn.default_security_list_id]
}

# ============================================================================
# Network Security Groups (per Oracle OKE docs for Flannel + public API)
# https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengnetworkconfig.htm
# ============================================================================

# --- API Endpoint NSG ---
resource "oci_core_network_security_group" "api_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-api-nsg-${var.environment}"
}

# API Ingress: workers (and the bastion, which lives in the same subnet) -> API on 6443.
# There is no rule from the internet: the API endpoint is private.
resource "oci_core_network_security_group_security_rule" "api_ingress_workers_6443" {
  network_security_group_id = oci_core_network_security_group.api_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# API Ingress: workers -> API on 12250 (OKE control plane)
resource "oci_core_network_security_group_security_rule" "api_ingress_workers_12250" {
  network_security_group_id = oci_core_network_security_group.api_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}

# API Ingress: ICMP path discovery from workers
resource "oci_core_network_security_group_security_rule" "api_ingress_icmp_workers" {
  network_security_group_id = oci_core_network_security_group.api_nsg.id
  direction                 = "INGRESS"
  protocol                  = "1" # ICMP
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"
  icmp_options {
    type = 3
    code = 4
  }
}

# API Egress: ALL to worker subnet
resource "oci_core_network_security_group_security_rule" "api_egress_workers" {
  network_security_group_id = oci_core_network_security_group.api_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = var.private_subnet_cidr
  destination_type          = "CIDR_BLOCK"
}

# API Egress: HTTPS to OCI services (image registry, OKE service, etc.)
resource "oci_core_network_security_group_security_rule" "api_egress_oci_services" {
  network_security_group_id = oci_core_network_security_group.api_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6" # TCP
  destination               = data.oci_core_services.all_services.services[0].cidr_block
  destination_type          = "SERVICE_CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# API Egress: ICMP path discovery
resource "oci_core_network_security_group_security_rule" "api_egress_icmp" {
  network_security_group_id = oci_core_network_security_group.api_nsg.id
  direction                 = "EGRESS"
  protocol                  = "1" # ICMP
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  icmp_options {
    type = 3
    code = 4
  }
}

# --- Worker Node NSG ---
resource "oci_core_network_security_group" "worker_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-worker-nsg-${var.environment}"
}

# Worker Ingress: ALL from other workers (flannel VXLAN, pod-to-pod, etc.)
resource "oci_core_network_security_group_security_rule" "worker_ingress_all_workers" {
  network_security_group_id = oci_core_network_security_group.worker_nsg.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"
}

# Worker Ingress: API -> kubelet (10250)
resource "oci_core_network_security_group_security_rule" "worker_ingress_api_kubelet" {
  network_security_group_id = oci_core_network_security_group.worker_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.public_subnet_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 10250
      max = 10250
    }
  }
}

# Worker Ingress: API -> OKE control plane (12250) — CRITICAL for node registration
resource "oci_core_network_security_group_security_rule" "worker_ingress_api_12250" {
  network_security_group_id = oci_core_network_security_group.worker_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.public_subnet_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}

# Worker Ingress: ICMP from anywhere (path MTU discovery)
resource "oci_core_network_security_group_security_rule" "worker_ingress_icmp" {
  network_security_group_id = oci_core_network_security_group.worker_nsg.id
  direction                 = "INGRESS"
  protocol                  = "1" # ICMP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  icmp_options {
    type = 3
    code = 4
  }
}

# Worker Ingress: SSH from VCN (emergency access)
resource "oci_core_network_security_group_security_rule" "worker_ingress_ssh" {
  network_security_group_id = oci_core_network_security_group.worker_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# Worker Egress: ALL to anywhere (NAT gateway for internet, images, updates)
resource "oci_core_network_security_group_security_rule" "worker_egress_all" {
  network_security_group_id = oci_core_network_security_group.worker_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# Worker Egress: OCI services (container registry, object storage, etc.)
resource "oci_core_network_security_group_security_rule" "worker_egress_oci_services" {
  network_security_group_id = oci_core_network_security_group.worker_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6" # TCP
  destination               = data.oci_core_services.all_services.services[0].cidr_block
  destination_type          = "SERVICE_CIDR_BLOCK"
}
