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
    Optional. A stable DNS hostname for the public Kubernetes API endpoint (e.g., `kube.mydomain.com`).
    If set, you MUST configure a DNS A record for this hostname pointing to your desired public entrypoint (e.g., Floating IP, Load Balancer IP).
    This hostname will be embedded in the cluster's certificates (SANs).
    If not set, the generated kubeconfig/talosconfig will use an IP address based on `output_mode_config_cluster_endpoint`.
    Internal cluster communication often uses `kube.[cluster_domain]`, which is handled automatically via /etc/hosts if `enable_alias_ip = true`.
  EOF
  default     = null
}

variable "location_name" {
  type        = string
  description = <<EOF
    The name of the location where the cluster will be created.
    This is used to determine the region and zone of the cluster and network.
    Possible values: fsn1, nbg1, hel1, ash, hil, sin
  EOF
  validation {
    condition     = contains(data.hcloud_locations.all.locations[*].name, var.location_name)
    error_message = "Invalid location name."
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
    Configure which endpoint address is written into the generated `talosconfig` and `kubeconfig` files.
    - `public_ip`: Use the public IP of the first control plane (or the Floating IP if enabled).
    - `private_ip`: Use the private IP of the first control plane (or the private Alias IP if enabled). Useful if accessing only via VPN/private network.
    - `cluster_endpoint`: Use the hostname defined in `cluster_api_host`. Requires `cluster_api_host` to be set.
  EOF
}

# Firewall
variable "firewall_id" {
  type        = string
  default     = null
  description = <<EOF
    ID of an existing Hetzner Cloud firewall to use instead of creating one.
    When set, the module will not create a firewall and will use this ID instead.
    This is useful to avoid chicken-and-egg issues when your IP changes:
    manage the firewall externally and pass its ID here.
  EOF
}

variable "firewall_use_current_ip" {
  type        = bool
  default     = false
  description = <<EOF
    If true, the current IP address will be used as the source for the firewall rules.
    ATTENTION: to determine the current IP, requests to public services are made:
    - IPv4 address is always fetched from https://ipv4.icanhazip.com
    - IPv6 address is only fetched from https://ipv6.icanhazip.com if enable_ipv6 = true
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
    If true, a private alias IP (defaulting to the .100 address within `node_ipv4_cidr`) will be configured on the control plane nodes.
    This enables a stable internal IP for the Kubernetes API server, reachable via `kube.[cluster_domain]`.
    The module automatically configures `/etc/hosts` on nodes to resolve `kube.[cluster_domain]` to this alias IP.
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
    The public key to be set in the servers. This key is used by Hetzner Cloud for initial server provisioning
    and for accessing the server in rescue mode. While Talos itself does not use this key for cluster operations,
    providing one prevents Hetzner from sending login credentials via email.
    If you don't set it, a dummy key will be generated and used.
  EOF
  type        = string
  default     = null
  sensitive   = true
}

variable "control_plane_nodes" {
  type = list(object({
    id     = number
    type   = string
    labels = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  description = <<EOF
    List of control plane node configurations.

    Each entry represents one control plane node.
    The total number of control planes must be odd (1, 3, 5) and at most 5.

    - id: Stable node id starting at 1 (used for naming and IP allocation).
    - type: Server type (cpx11, cpx12, cpx21, cpx22, cpx31, cpx32, cpx41, cpx42, cpx51, cpx52, cpx62, cax11, cax21, cax31, cax41, ccx13, ccx23, ccx33, ccx43, ccx53, ccx63, cx22, cx23, cx32, cx33, cx42, cx43, cx52, cx53)
    - labels: Map of Kubernetes labels to apply to this node (default: {})
    - taints: List of Kubernetes taints to apply to this node (default: [])
  EOF
  validation {
    condition     = length(var.control_plane_nodes) % 2 == 1 && length(var.control_plane_nodes) <= 5
    error_message = "The number of control plane nodes must be an odd number (1, 3, 5) and at most 5."
  }
  validation {
    condition = alltrue([
      for node in var.control_plane_nodes : contains([
        "cpx11", "cpx12", "cpx21", "cpx22", "cpx31", "cpx32", "cpx41", "cpx42", "cpx51", "cpx52", "cpx62",
        "cax11", "cax21", "cax31", "cax41",
        "ccx13", "ccx23", "ccx33", "ccx43", "ccx53", "ccx63",
        "cx22", "cx23", "cx32", "cx33", "cx42", "cx43", "cx52", "cx53"
      ], node.type)
    ])
    error_message = "Invalid control plane server type in control_plane_nodes."
  }
  validation {
    condition = (
      length(setsubtract(
        toset([for node in var.control_plane_nodes : node.id]),
        toset(range(1, length(var.control_plane_nodes) + 1))
      )) == 0 &&
      length(setsubtract(
        toset(range(1, length(var.control_plane_nodes) + 1)),
        toset([for node in var.control_plane_nodes : node.id])
      )) == 0
    )
    error_message = "control_plane_nodes id must be unique and contiguous starting at 1 (1..N)."
  }
  validation {
    condition = alltrue(flatten([
      for node in var.control_plane_nodes : [
        for taint in node.taints : contains(["NoSchedule", "PreferNoSchedule", "NoExecute"], taint.effect)
      ]
    ]))
    error_message = "Invalid taint effect in control_plane_nodes. Allowed values: NoSchedule, PreferNoSchedule, NoExecute."
  }
}


variable "control_plane_allow_schedule" {
  type        = bool
  default     = false
  description = <<EOF
    If true, control plane nodes will be schedulable (i.e., can run workloads).
    If false (default), control plane nodes will be tainted to prevent scheduling of regular workloads.
    Note: If you set worker_nodes = [], control plane nodes will automatically be schedulable regardless of this setting.
  EOF
}

variable "worker_nodes" {
  type = list(object({
    id     = number
    type   = string
    labels = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default     = []
  description = <<EOF
    List of worker node configurations.

    Each entry represents one worker node.

    - id: Stable node id starting at 1 (used for naming and IP allocation).
    - type: Server type (cpx11, cpx12, cpx21, cpx22, cpx31, cpx32, cpx41, cpx42, cpx51, cpx52, cpx62, cax11, cax21, cax31, cax41, ccx13, ccx23, ccx33, ccx43, ccx53, ccx63, cx22, cx23, cx32, cx33, cx42, cx43, cx52, cx53)
    - labels: Map of Kubernetes labels to apply to this node (default: {})
    - taints: List of Kubernetes taints to apply to this node (default: [])
    
    Example:
    worker_nodes = [
      {
        id   = 1
        type = "cx22"
      },
      {
        id    = 2
        type   = "cax21"
        labels = {
          "node.kubernetes.io/arch" = "arm64"
        }
        taints = [
          {
            key    = "workload-type"
            value  = "gpu"
            effect = "NoSchedule"
          }
        ]
      }
    ]
  EOF
  validation {
    condition = alltrue([
      for node in var.worker_nodes : contains([
        "cpx11", "cpx12", "cpx21", "cpx22", "cpx31", "cpx32", "cpx41", "cpx42", "cpx51", "cpx52", "cpx62",
        "cax11", "cax21", "cax31", "cax41",
        "ccx13", "ccx23", "ccx33", "ccx43", "ccx53", "ccx63",
        "cx22", "cx23", "cx32", "cx33", "cx42", "cx43", "cx52", "cx53"
      ], node.type)
    ])
    error_message = "Invalid worker server type in worker_nodes."
  }
  validation {
    condition = (
      length(setsubtract(
        toset([for node in var.worker_nodes : node.id]),
        toset(range(1, length(var.worker_nodes) + 1))
      )) == 0 &&
      length(setsubtract(
        toset(range(1, length(var.worker_nodes) + 1)),
        toset([for node in var.worker_nodes : node.id])
      )) == 0
    )
    error_message = "worker_nodes id must be unique and contiguous starting at 1 (1..N)."
  }
  validation {
    condition = alltrue(flatten([
      for node in var.worker_nodes : [
        for taint in node.taints : contains(["NoSchedule", "PreferNoSchedule", "NoExecute"], taint.effect)
      ]
    ]))
    error_message = "Invalid taint effect in worker_nodes. Allowed values: NoSchedule, PreferNoSchedule, NoExecute."
  }
  validation {
    condition     = length(var.worker_nodes) <= 99
    error_message = "Total number of worker nodes must be less than 100."
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

variable "talos_control_plane_extra_config_patches" {
  type        = list(string)
  default     = []
  description = "List of additional YAML configuration patches to apply to the Talos machine configuration for control plane nodes."
}

variable "talos_worker_extra_config_patches" {
  type        = list(string)
  default     = []
  description = "List of additional YAML configuration patches to apply to the Talos machine configuration for worker nodes."
}


variable "tailscale" {
  type = object({
    enabled  = optional(bool)
    auth_key = optional(string)
  })
  default = {
    enabled  = false
    auth_key = ""
  }
  description = "The auth key to use for Tailscale."
  validation {
    condition     = var.tailscale.enabled == false || (var.tailscale.enabled == true && var.tailscale.auth_key != "")
    error_message = "If tailscale is enabled, an auth_key must be provided."
  }
}

variable "registries" {
  type = object({
    mirrors = optional(map(object({
      endpoints    = list(string)
      overridePath = optional(bool)
    })))
    config = optional(map(object({
      auth = object({
        username      = optional(string)
        password      = optional(string)
        auth          = optional(string)
        identityToken = optional(string)
      })
    })))
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

variable "deploy_cilium" {
  type        = bool
  default     = true
  description = <<EOF
    If true, Cilium CNI will be deployed via Terraform.

    Set to false after initial bootstrap to hand off management to GitOps tools (e.g., Argo CD).
    After toggling, run `terraform apply` once to remove the Cilium resources from Terraform state.

    Note: This module uses `kubectl_manifest.apply_only = true`, so disabling Cilium in Terraform will not delete it from the cluster.
  EOF
}

variable "deploy_prometheus_operator_crds" {
  type        = bool
  default     = false
  description = <<EOF
    If true, the Prometheus Operator CRDs will be deployed via Terraform.

    Set to false after initial bootstrap to hand off management to GitOps tools (e.g., Argo CD).
    After toggling, run `terraform apply` once to remove the CRDs from Terraform state.

    Note: This module uses `kubectl_manifest.apply_only = true`, so disabling the CRDs in Terraform will not delete them from the cluster.
  EOF
}

variable "prometheus_operator_crds_version" {
  type        = string
  default     = null
  description = "The version of the Prometheus Operator CRDs Helm chart to deploy. If not set, the latest version will be used."
}

variable "deploy_hcloud_ccm" {
  type        = bool
  default     = true
  description = <<EOF
    If true, the Hetzner Cloud Controller Manager will be deployed via Terraform.

    Set to false after initial bootstrap to hand off management to GitOps tools (e.g., Argo CD).
    After toggling, run `terraform apply` once to remove the CCM resources from Terraform state.

    Note: This module uses `kubectl_manifest.apply_only = true`, so disabling the CCM in Terraform will not delete it from the cluster.
  EOF
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
