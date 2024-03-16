machine:
  certSANs: ${format("%#v",split(",",certSANs))}
  kubelet:
    extraArgs:
      cloud-provider: external
    clusterDNS:
      - 169.254.2.53
      - ${cidrhost(split(",",serviceSubnets)[0], 10)}
    nodeIP:
      validSubnets: ${format("%#v",split(",",nodeSubnets))}
  network:
    interfaces:
      - interface: dummy0
        addresses:
          - 169.254.2.53/32
    extraHostEntries:
      ${indent(2, format("%#v", [for entry in split(",", extraHostEntries): {
        ip: element(split(":", entry), 0),
        aliases: [ element(split(":", entry), 1) ]
      } ]))}
  sysctls:
    net.core.somaxconn: 65535
    net.core.netdev_max_backlog: 4096
  features:
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles:
        - os:reader
      allowedKubernetesNamespaces:
        - kube-system
  time:
    servers:
      - ntp1.hetzner.de
      - ntp2.hetzner.com
      - ntp3.hetzner.net
      - time.cloudflare.com
cluster:
  allowSchedulingOnControlPlanes: ${allowSchedulingOnControlPlanes}
  network:
    dnsDomain: ${domain}
    podSubnets: ${format("%#v",split(",",podSubnets))}
    serviceSubnets: ${format("%#v",split(",",serviceSubnets))}
    cni:
      name: none
  proxy:
    disabled: true
  apiServer:
    certSANs: ${format("%#v",split(",",certSANs))}
  controllerManager:
    extraArgs:
      cloud-provider: external
      node-cidr-mask-size-ipv4: ${nodeCidrMaskSizeIpv4}
  etcd:
    advertisedSubnets:
      - ${nodeSubnets}
    extraArgs:
      listen-metrics-urls: http://0.0.0.0:2381 # required for kube-prometheus-stack
  inlineManifests:
    - name: hcloud-secret
      contents: |-
        apiVersion: v1
        kind: Secret
        type: Opaque
        metadata:
          name: hcloud
          namespace: kube-system
        data:
          network: ${base64encode(hcloudNetwork)}
          token: ${base64encode(hcloudToken)}
  externalCloudProvider:
    enabled: true
