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

variable "cluster_domain" {
  type        = string
  default     = "cluster.local"
  description = "The domain name of the cluster."
}

variable "cluster_prefix" {
  type        = bool
  default     = false
  description = "Prefix Hetzner Cloud resources with the cluster name."
}

variable "cluster_api_host" {
  type        = string
  description = <<EOF
    The entrypoint of the cluster. Must be a valid domain name. If not set, `kube.[cluster_domain]` will be used.
    You should create a DNS record pointing to either the load balancer, floating IP, or alias IP.
  EOF
  default     = null
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

variable "output_mode_config_cluster_endpoint" {
  type    = string
  default = "public_ip"
  validation {
    condition     = contains(["public_ip", "private_ip", "cluster_endpoint"], var.output_mode_config_cluster_endpoint)
    error_message = "Invalid output mode for kube and talos config endpoint."
  }
  description = <<EOF
    Configure which IP addresses are to be used in Talos- and Kube-config output.
    Possible values: public_ip, private_ip, cluster_endpoint
    ATTENTION: If 'cluster_endpoint' is selected, 'cluster_api_host' is used and should be set, too.
  EOF
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
variable "enable_floating_ip" {
  type        = bool
  default     = false
  description = "If true, a floating IP will be created and assigned to the control plane nodes."
}

variable "enable_alias_ip" {
  type        = bool
  default     = true
  description = <<EOF
    If true, an alias IP (cidrhost(node_ipv4_cidr, 100)) will be created and assigned to the control plane nodes.
  EOF
}

variable "floating_ip" {
  type = object({
    id = number,
  })
  default     = null
  description = <<EOF
    The Floating IP (ID) to use for the control plane nodes.
    If null (default), a new floating IP will be created.
    (using object because of https://github.com/hashicorp/terraform/issues/26755)
  EOF
}

variable "enable_ipv6" {
  type        = bool
  default     = false
  description = <<EOF
    If true, the servers will have an IPv6 address.
    IPv4/IPv6 dual-stack is actually not supported, it keeps being an IPv4 single stack. PRs welcome!
  EOF
}

variable "enable_kube_span" {
  type        = bool
  default     = false
  description = "If true, the KubeSpan Feature (with \"Kubernetes registry\" mode) will be enabled."
}

variable "network_ipv4_cidr" {
  description = "The main network cidr that all subnets will be created upon."
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_ipv4_cidr" {
  description = "Node CIDR, used for the nodes (control plane and worker nodes) in the cluster."
  type        = string
  default     = "10.0.1.0/24"
}

variable "pod_ipv4_cidr" {
  description = "Pod CIDR, used for the pods in the cluster."
  type        = string
  default     = "10.0.16.0/20"
}

variable "service_ipv4_cidr" {
  description = "Service CIDR, used for the services in the cluster."
  type        = string
  default     = "10.0.8.0/21"
}

# Server
variable "talos_version" {
  type        = string
  description = "The version of talos features to use in generated machine configurations."
}

variable "ssh_public_key" {
  description = <<EOF
    The public key to be set in the servers. It is not used in any way.
    If you don't set it, a dummy key will be generated and used.
    Unfortunately, it is still required, otherwise the Hetzner will sen E-Mails with login credentials.
  EOF
  type        = string
  default     = null
  sensitive   = true
}

variable "control_plane_count" {
  type        = number
  description = <<EOF
    The number of control plane nodes to create.
    Must be an odd number. Maximum 5.
  EOF
  validation {
    // 0 is required for debugging (create configs etc. without servers)
    condition     = var.control_plane_count == 0 || (var.control_plane_count % 2 == 1 && var.control_plane_count <= 5)
    error_message = "The number of control plane nodes must be an odd number."
  }
}

variable "control_plane_server_type" {
  type        = string
  description = <<EOF
    The server type to use for the control plane nodes.
    Possible values: cx11, cx21, cx22, cx31, cx32, cx41, cx42, cx51, cx52, cpx11, cpx21, cpx31,
    cpx41, cpx51, cax11, cax21, cax31, cax41, ccx13, ccx23, ccx33, ccx43, ccx53, ccx63
  EOF
  validation {
    condition = contains([
      "cx11", "cx21", "cx22", "cx31", "cx32", "cx41", "cx42", "cx51", "cx52",
      "cpx11", "cpx21", "cpx31", "cpx41", "cpx51",
      "cax11", "cax21", "cax31", "cax41",
      "ccx13", "ccx23", "ccx33", "ccx43", "ccx53", "ccx63"
    ], var.control_plane_server_type)
    error_message = "Invalid control plane server type."
  }
}

variable "worker_count" {
  type        = number
  default     = 0
  description = "The number of worker nodes to create. Maximum 99."
  validation {
    condition     = var.worker_count <= 99
    error_message = "The number of worker nodes must be less than 100."
  }
}

variable "worker_server_type" {
  type        = string
  default     = "cx11"
  description = <<EOF
    The server type to use for the worker nodes.
    Possible values: cx11, cx21, cx22, cx31, cx32, cx41, cx42, cx51, cx52, cpx11, cpx21, cpx31,
    cpx41, cpx51, cax11, cax21, cax31, cax41, ccx13, ccx23, ccx33, ccx43, ccx53, ccx63
  EOF
  validation {
    condition = contains([
      "cx11", "cx21", "cx22", "cx31", "cx32", "cx41", "cx42", "cx51", "cx52",
      "cpx11", "cpx21", "cpx31", "cpx41", "cpx51",
      "cax11", "cax21", "cax31", "cax41",
      "ccx13", "ccx23", "ccx33", "ccx43", "ccx53", "ccx63"
    ], var.worker_server_type)
    error_message = "Invalid worker server type."
  }
}

variable "disable_x86" {
  type        = bool
  default     = false
  description = "If true, x86 images will not be used."
}

variable "disable_arm" {
  type        = bool
  default     = false
  description = "If true, arm images will not be used."
}

# Talos
variable "kubelet_extra_args" {
  type        = map(string)
  default     = {}
  description = "Additional arguments to pass to kubelet."
}

variable "kube_api_extra_args" {
  type        = map(string)
  default     = {}
  description = "Additional arguments to pass to the kube-apiserver."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.30.3"
  description = <<EOF
    The Kubernetes version to use. If not set, the latest version supported by Talos is used: https://www.talos.dev/v1.7/introduction/support-matrix/
    Needs to be compatible with the `cilium_version`: https://docs.cilium.io/en/stable/network/kubernetes/compatibility/
  EOF
}

variable "sysctls_extra_args" {
  type        = map(string)
  default     = {}
  description = "Additional sysctls to set."
}

variable "kernel_modules_to_load" {
  type = list(object({
    name       = string
    parameters = optional(list(string))
  }))
  default     = null
  description = "List of kernel modules to load."
}

variable "registries" {
  type = object({
    mirrors = map(object({
      endpoints    = list(string)
      overridePath = optional(bool)
    }))
  })
  default     = null
  description = <<EOF
    List of registry mirrors to use.
    Example:
    ```
    registries = {
      mirrors = {
        "docker.io" = {
          endpoints = [
            "http://localhost:5000",
            "https://docker.io"
          ]
        }
      }
    }
    ```
    https://www.talos.dev/v1.6/reference/configuration/v1alpha1/config/#Config.machine.registries
  EOF
}

# Deployments
variable "cilium_version" {
  type        = string
  default     = "1.16.2"
  description = <<EOF
    The version of Cilium to deploy. If not set, the `1.16.0` version will be used.
    Needs to be compatible with the `kubernetes_version`: https://docs.cilium.io/en/stable/network/kubernetes/compatibility/
  EOF
}

variable "cilium_values" {
  type        = list(string)
  default     = null
  description = <<EOF
    The values.yaml file to use for the Cilium Helm chart.
    If null (default), the default values will be used.
    Otherwise, the provided values will be used.
    Example:
    ```
    cilium_values  = [templatefile("cilium/values.yaml", {})]
    ```
  EOF
}

variable "cilium_enable_encryption" {
  type        = bool
  default     = false
  description = "Enable transparent network encryption."
}

variable "cilium_enable_service_monitors" {
  type        = bool
  default     = false
  description = <<EOF
    If true, the service monitors for Prometheus will be enabled.
    Service Monitor requires monitoring.coreos.com/v1 CRDs.
    You can use the deploy_prometheus_operator_crds variable to deploy them.
  EOF
}

variable "deploy_prometheus_operator_crds" {
  type        = bool
  default     = false
  description = "If true, the Prometheus Operator CRDs will be deployed."
}

variable "hcloud_ccm_version" {
  type        = string
  default     = null
  description = "The version of the Hetzner Cloud Controller Manager to deploy. If not set, the latest version will be used."
}

variable "disable_talos_coredns" {
  type        = bool
  default     = false
  description = "If true, the CoreDNS delivered by Talos will not be deployed."
}

variable "extraManifests" {
  type        = list(string)
  default     = null
  description = "Additional manifests URL applied during Talos bootstrap."
}
