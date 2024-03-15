# General
variable "hcloud_token" {
  type        = string
  description = "The Hetzner Cloud API token."
  sensitive   = true
}

variable "talos_version" {
  type        = string
  default     = "v1.6.0"
  description = "The version of Talos to use for the cluster."
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster."
}

# Firewall
variable "firewall_use_current_ip" {
  type        = bool
  default     = false
  description = <<EOF
    If true, the current IP address will be used as the source for the firewall rules.
    ATTENTION: to determine the current IP, a request to a public service (https://ipv4.icanhazip.com) is made.
  EOF
}

variable "extra_firewall_rules" {
  type        = list(any)
  default     = []
  description = "Additional firewall rules to apply to the cluster."
}

variable "firewall_kube_api_source" {
  type        = list(string)
  default     = null
  description = <<EOF
    Source networks that have Kube API access to the servers.
    If null (default), the all traffic is blocked.
    If set, this overrides the firewall_use_current_ip setting.
  EOF
}

variable "firewall_talos_api_source" {
  type        = list(string)
  default     = null
  description = <<EOF
    Source networks that have Talos API access to the servers.
    If null (default), the all traffic is blocked.
    If set, this overrides the firewall_use_current_ip setting.
  EOF
}

