# Supported versions

This module supports the following stable Talos versions and Kubernetes ranges.
Terraform rejects other combinations before deployment.

| Talos series | Minimum Talos version | Kubernetes range |
| --- | --- | --- |
| 1.13 | `v1.13.11` | `>= 1.31.0, < 1.36.99` |
| 1.14 | `v1.14.3` | `>= 1.32.0, < 1.37.99` |

Use `vMAJOR.MINOR.PATCH` for `talos_version` and `MAJOR.MINOR.PATCH` for
`kubernetes_version`. Leading zeroes, prereleases, and build metadata are not
supported. Both inputs are required.

Later stable Talos patches within these two minor series are accepted. New minor
and major series are rejected until this module adds explicit support. These
minimum patch versions are fixed for this module release line. A higher minimum
or removal of a supported series requires a breaking release.

The Talos provider is restricted to `0.12.x`. A new provider minor series requires
configuration tests before this constraint changes.

## Images and existing clusters

The Talos boot image and `talos_version` must match. The default snapshot lookup
requires both `os=talos` and `version=<talos_version>` labels. Images without the
matching version label are not selected. If you supply an image or ISO ID, you
must check its version yourself.

Changing a version input does not upgrade an existing cluster. This module ignores
changes to server `user_data`, `image`, and `iso`. Follow the Talos upgrade
procedures and the [migration guide](MIGRATIONS.md). New nodes use the configured
versions and images.

The deprecated Packer template applies the same Talos version limits. Its default
is `v1.14.3`. This does not change its deprecated status; use
[terraform-provider-imager](https://github.com/hcloud-talos/terraform-provider-imager)
for new image builds.

## Cilium

Cilium compatibility is not enforced by the version checks. The default is
`1.20.3`; the examples use Kubernetes `1.35.0`. Cilium 1.20 documents tested support
for Kubernetes 1.33–1.36. If you select another Kubernetes version, choose a
compatible Cilium release yourself, or manage the CNI outside this module.

Do not assume that every Kubernetes version supported by Talos is also supported
by the default Cilium release. Check the
[Cilium compatibility matrix](https://docs.cilium.io/en/stable/network/kubernetes/compatibility/).

## Configuration formats

Talos 1.13 uses the legacy `machine` and `cluster` patches. Talos 1.14 uses dedicated
documents for Kubernetes, hostname, host DNS, and installation settings. Settings
that do not conflict with generated documents remain in the legacy document.

For Talos 1.14, use the corresponding document kinds in extra configuration
patches. For example, replace `machine.kubelet.extraArgs` with
`KubeletConfig.extraArgs`. Do not set a legacy field when its new document is
present. Talos rejects that combination. See [MIGRATIONS.md](MIGRATIONS.md) for an
example.

## Tests and policy updates

[supported_versions.json](supported_versions.json) defines the Terraform support
matrix. The version limits come from these upstream sources:

- [Talos v1.13.11 release](https://github.com/siderolabs/talos/releases/tag/v1.13.11)
- [Talos 1.13 compatibility limits](https://github.com/siderolabs/talos/blob/v1.13.11/pkg/machinery/compatibility/talos113/talos113.go)
- [Talos v1.14.3 release](https://github.com/siderolabs/talos/releases/tag/v1.14.3)
- [Talos 1.14 compatibility limits](https://github.com/siderolabs/talos/blob/v1.14.3/pkg/machinery/compatibility/talos114/talos114.go)
- [Cilium 1.20 compatibility](https://github.com/cilium/cilium/blob/v1.20.3/Documentation/network/kubernetes/compatibility.rst)

To update the policy:

1. Check the versioned upstream release and compatibility sources.
2. Update the matrix, the Packer validation bounds, and this document together.
   Packer cannot refer to the shared matrix from variable validation.
3. Update the configuration patches if the generated format changed.
4. Update the examples, minimum-version tests, and CI validator version.
5. Run `./tests/run.sh` with Terraform and OpenTofu. Run
   `python3 tests/packer.py` with Packer installed.
6. Record any new minimum or removed series as a breaking change.

The tests use the production variable definitions, patches, and Talos data
sources with fixed network inputs. They generate real machine secrets and
configuration, then run `talosctl validate`. They test accepted and rejected
versions, clusters with and without workers, labels, taints, scheduling, CNI,
DNS, manifests, installer settings, and extra patches.

These tests do not create cloud resources or connect to a cluster. They do not
prove that a deployed cluster becomes healthy. See [tests/README.md](tests/README.md)
for local test requirements.
