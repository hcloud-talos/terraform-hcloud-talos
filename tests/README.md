# Tests

## Image and ISO selection

Run from the repository root:

```sh
./tests/images.sh
IAC_CLI=tofu ./tests/images.sh
./tests/images.sh -filter=generated_images.tftest.hcl
```

Requirements:

- Terraform 1.10 or later, or a CI-tested OpenTofu version.
- Network access to download the Hetzner provider.

The runner copies production image selection, variables, and version validation
into a temporary module. The fixture calls that module with both fixed IDs and
IDs from `terraform_data` resources. The plan tests run before those IDs are
known. The apply tests use only local `terraform_data` resources.

The Hetzner provider is mocked. No token, cloud resources, or cluster access is
required. Lookup tests check the source count and selectors. The provider marks
the lookup ID as optional rather than computed, so the mock cannot supply it.
Other tests check the selected image and ISO IDs directly.

The tests also cover legacy scalar inputs, disabled lookup and ISO attachment,
invalid IDs, and conflicting source inputs. Temporary configuration and state
are removed when the runner exits.

## Configuration and versions

Run from the repository root:

```sh
./tests/run.sh
IAC_CLI=tofu ./tests/run.sh
python3 tests/packer.py
```

Requirements:

- Terraform 1.10 or later, or a CI-tested OpenTofu version.
- `talosctl` 1.14.3 for configuration validation. Earlier 1.14 patches can also
  validate the current fixtures, but CI uses the supported minimum patch.
- Packer and Python 3 for the Packer tests.
- Network access to download providers and the Packer plugin.

The runner copies the production variables, support matrix, patches, and Talos
configuration data sources into a temporary directory. The fixture supplies fixed
network inputs instead of cloud resources. The location variable is separate in
`location.tf` because its validation requires a Hetzner query.

The partial fixture is stored as `configuration/main.tf.tmpl`, not as a standalone
Terraform module. The runner copies it to `main.tf` and checks the format of the
assembled configuration before running the tests.

Only the real Talos provider and the built-in `terraform_data` resource are used.
The local provisioner runs `talosctl validate`; it does not contact a node.
Temporary secrets, configuration, and state are removed when the runner exits.
Do not add cloud resources, bootstrap resources, or cluster access to this fixture.

The Packer tests copy only the tracked template. They do not load local auto
variable files or use a real Hetzner token. They run `packer init` and
`packer validate`, never `packer build`.

To run one Terraform test file:

```sh
./tests/run.sh -filter=configuration.tftest.hcl
./tests/run.sh -filter=versions.tftest.hcl
```
