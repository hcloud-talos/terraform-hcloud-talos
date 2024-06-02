# Retrieve the public IP address of the current machine if the firewall should be opened for the current IP
data "http" "personal_ipv4" {
  count = var.firewall_use_current_ip ? 1 : 0
  url   = "https://ipv4.icanhazip.com"
}

data "http" "personal_ipv6" {
  count = var.firewall_use_current_ip ? 1 : 0
  url   = "https://ipv6.icanhazip.com"
}

locals {
  current_ips = var.firewall_use_current_ip ? [
    "${chomp(data.http.personal_ipv4[0].response_body)}/32",
    "${chomp(data.http.personal_ipv6[0].response_body)}/128",
  ] : []

  base_firewall_rules = concat(
    var.firewall_kube_api_source == null && !var.firewall_use_current_ip ? [] : [
      {
        description = "Allow Incoming Requests to Kube API Server"
        direction   = "in"
        protocol    = "tcp"
        port        = "6443"
        source_ips  = var.firewall_kube_api_source != null ? var.firewall_kube_api_source : local.current_ips
      }
    ],
    var.firewall_talos_api_source == null && !var.firewall_use_current_ip ? [] : [
      {
        description = "Allow Incoming Requests to Talos API Server"
        direction   = "in"
        protocol    = "tcp"
        port        = "50000"
        source_ips  = var.firewall_talos_api_source != null ? var.firewall_talos_api_source : local.current_ips
      }
    ],
  )

  # create a new firewall list based on base_firewall_rules but with direction-protocol-port as key
  # this is needed to avoid duplicate rules
  firewall_rules = {
    for rule in local.base_firewall_rules :
    format("%s-%s-%s",
      lookup(rule, "direction", "null"),
      lookup(rule, "protocol", "null"),
      lookup(rule, "port", "null")
    ) => rule
  }

  # do the same for var.extra_firewall_rules
  extra_firewall_rules = {
    for rule in var.extra_firewall_rules :
    format("%s-%s-%s",
      lookup(rule, "direction", "null"),
      lookup(rule, "protocol", "null"),
      lookup(rule, "port", "null")
    ) => rule
  }

  # merge the two lists
  firewall_rules_merged = merge(local.firewall_rules, local.extra_firewall_rules)

  # convert the merged list back to a list
  firewall_rules_list = values(local.firewall_rules_merged)
}

resource "hcloud_firewall" "this" {
  name = var.cluster_name
  dynamic "rule" {
    for_each = local.firewall_rules_list
    //noinspection HILUnresolvedReference
    content {
      description     = rule.value.description
      direction       = rule.value.direction
      protocol        = rule.value.protocol
      port            = lookup(rule.value, "port", null)
      destination_ips = lookup(rule.value, "destination_ips", [])
      source_ips      = lookup(rule.value, "source_ips", [])
    }
  }
  labels = {
    "cluster" = var.cluster_name
  }
}
