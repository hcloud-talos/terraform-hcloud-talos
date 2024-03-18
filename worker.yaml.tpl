machine:
  kubelet:
    extraArgs:
      cloud-provider: external
      rotate-server-certificates: true
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
  time:
    servers:
      - ntp1.hetzner.de
      - ntp2.hetzner.com
      - ntp3.hetzner.net
      - time.cloudflare.com
cluster:
  network:
    dnsDomain: ${domain}
    podSubnets: ${format("%#v",split(",",podSubnets))}
    serviceSubnets: ${format("%#v",split(",",serviceSubnets))}
  proxy:
    disabled: true
