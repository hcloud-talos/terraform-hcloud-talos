# General
variable "hcloud_token" {
  type        = string
  description = "The Hetzner Cloud API token."
  sensitive   = true
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster."
}

variable "datacenter_name" {
  type        = string
  description = <<EOF
    The name of the datacenter where the cluster will be created.
    This is used to determine the region and zone of the cluster and network.
    Possible values: fsn1-dc14, nbg1-dc3, hel1-dc2, ash-dc1, hil-dc1
  EOF
  validation {
    condition     = contains(["fsn1-dc14", "nbg1-dc3", "hel1-dc2", "ash-dc1", "hil-dc1"], var.datacenter_name)
    error_message = "Invalid datacenter name."
  }
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

# Network
variable "network_ipv4_cidr" {
  description = "The main network cidr that all subnets will be created upon."
  type        = string
  default     = "10.0.0.0/16"
}

# Server
variable "talos_version" {
  type        = string
  default     = "v1.6.6"
  description = "The version of Talos to use for the cluster."
}

variable "ssh_public_key" {
  description = <<EOF
    The public key to be set in the servers. It is not used in any way.
    Unfortunately, it is still required, otherwise the Hetzner will sen E-Mails with login credentials.
  EOF
  type        = string
  sensitive   = true
}

variable "control_plane_count" {
  type        = number
  description = <<EOF
    The number of control plane nodes to create.
    Must be an odd number.
  EOF
  validation {
    condition     = var.control_plane_count % 2 == 1
    error_message = "The number of control plane nodes must be an odd number."
  }
}

variable "control_plane_server_type" {
  type        = string
  description = <<EOF
    The server type to use for the control plane nodes.
    Possible values: cx11, cx21, cx31, cx41, cx51, cpx11, cpx21, cpx31, cpx41,
    cpx51, cax11, cax21, cax31, cax41, ccx13, ccx23, ccx33, ccx43, ccx53, ccx63
  EOF
  validation {
    condition = contains([
      "cx11", "cx21", "cx31", "cx41", "cx51",
      "cpx11", "cpx21", "cpx31", "cpx41", "cpx51",
      "cax11", "cax21", "cax31", "cax41",
      "ccx13", "ccx23", "ccx33", "ccx43", "ccx53", "ccx63"
    ], var.control_plane_server_type)
    error_message = "Invalid control plane server type."
  }
}

variable "worker_count" {
  type        = number
  description = "The number of worker nodes to create."
}

variable "worker_server_type" {
  type        = string
  description = <<EOF
    The server type to use for the worker nodes.
    Possible values: cx11, cx21, cx31, cx41, cx51, cpx11, cpx21, cpx31, cpx41,
    cpx51, cax11, cax21, cax31, cax41, ccx13, ccx23, ccx33, ccx43, ccx53, ccx63
  EOF
  validation {
    condition = contains([
      "cx11", "cx21", "cx31", "cx41", "cx51",
      "cpx11", "cpx21", "cpx31", "cpx41", "cpx51",
      "cax11", "cax21", "cax31", "cax41",
      "ccx13", "ccx23", "ccx33", "ccx43", "ccx53", "ccx63"
    ], var.worker_server_type)
    error_message = "Invalid worker server type."
  }
}
