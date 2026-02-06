# Build Talos Images for Hetzner Cloud

This directory contains Packer configuration to build Talos OS images suitable for use with Hetzner Cloud.

> [!TIP]
> It's good practice to **always** create a `_packer/hcloud.auto.pkrvars.hcl` file to explicitly set the `talos_version`. This ensures the Packer build uses the exact Talos version you intend to deploy with Terraform, preventing potential mismatches if the default value in `talos-hcloud.pkr.hcl` is outdated or if you are using custom images from the Image Factory.
> Your `hcloud.auto.pkrvars.hcl` would simply contain:
>
> ```hcl
> # _packer/hcloud.auto.pkrvars.hcl
> talos_version = "v1.7.0" # Replace with your desired Talos version
>
> # Optionally, set custom server type for building snapshot:
> # server_type_arm = "cax21"
> # server_type_x86 = "cx33"
>
> # Optionally, Hetzner Cloud location (region) where the temporary build server is created.
> # Use a location where the provided server types are available.
> # server_location = "fsn1"
>
> # Optionally, add custom image URLs if using the Image Factory:
> # image_url_arm = "https://factory.talos.dev/image/<SCHEMATIC_ID>/<TALOS_VERSION>/hcloud-arm64.raw.xz"
> # image_url_x86 = "https://factory.talos.dev/image/<SCHEMATIC_ID>/<TALOS_VERSION>/hcloud-amd64.raw.xz"
> ```

## Simple Usage (Default Images)

To build the standard Talos images (ARM and x86) without any custom extensions, simply run the `create.sh` script:

```bash
./create.sh
```

This script will:

1. Check if Packer is installed.
2. Prompt for your Hetzner Cloud API token (`HCLOUD_TOKEN`) if it's not set as an environment variable.
3. Initialize Packer.
4. Run `packer build` using the default image URLs defined in `talos-hcloud.pkr.hcl`.
5. Store the resulting snapshots in your Hetzner Cloud project.

The Talos OS version used for the default images is defined by the `talos_version` variable in `talos-hcloud.pkr.hcl`. If you haven't created `hcloud.auto.pkrvars.hcl` to override it, this default value will be used.

## Role-Specific Images (Different Extensions for Control Plane vs Workers)

If you need different Talos extensions for control plane and worker nodes (e.g., tailscale only on control plane nodes), you can build role-specific images.

### Schematic Files

Two schematic files define the extensions for each role:

- `schematic-control-plane.yaml` - Extensions for control plane nodes (includes tailscale)
- `schematic-worker.yaml` - Extensions for worker nodes (no tailscale)

Customize these files to include the extensions you need for each node type.

### Building Role-Specific Images

```bash
# Build images for both roles (control-plane and worker)
./create.sh --roles

# Build only control-plane images
./create.sh control-plane

# Build only worker images
./create.sh worker
```

The script will:

1. Read the appropriate schematic file for each role
2. Submit it to the Talos Image Factory to get a schematic ID
3. Build images with the `role` label set (e.g., `role=control-plane` or `role=worker`)

### Using Role-Specific Images in Terraform

After building role-specific images, configure Terraform to use them:

```hcl
module "cluster" {
  source = "..."

  # Select images by role label
  control_plane_image_selector = "os=talos,role=control-plane"
  worker_image_selector        = "os=talos,role=worker"

  # ... other variables
}
```

The default selector `os=talos` works with generic images (built without `--roles`).

## Advanced Usage: Adding Extensions to the Talos Image

If you need to include additional system extensions in your Talos images (e.g., for specific storage drivers or tools), you can use the Talos Image Factory.

1. **Define Extensions:**
   Adjust the `schematic.yaml` file to include the official or custom extensions you need. The current file includes examples for `iscsi-tools`, `util-linux-tools`, and `binfmt-misc`.

2. **Generate Schematic ID:**
   Use the Talos Image Factory endpoint to generate a unique ID for your schematic configuration:

   ```shell
   curl -X POST --data-binary @schematic.yaml https://factory.talos.dev/schematics
   ```

   This command will return a JSON response containing the schematic ID.

3. **Get Custom Image URLs:**
   Use the schematic ID and the desired Talos version to construct the URLs for the custom images:

   - ARM: `https://factory.talos.dev/image/<SCHEMATIC_ID>/<TALOS_VERSION>/hcloud-arm64.raw.xz`
   - x86: `https://factory.talos.dev/image/<SCHEMATIC_ID>/<TALOS_VERSION>/hcloud-amd64.raw.xz`

   Replace `<SCHEMATIC_ID>` with the ID obtained in the previous step and `<TALOS_VERSION>` with the target Talos version (e.g., `v1.7.0`).

4. **Override Packer Variables:**
   Create a file named `hcloud.auto.pkrvars.hcl` in this directory to provide the custom image URLs and the corresponding Talos version to Packer. The file should look like this:

   ```hcl
   # _packer/hcloud.auto.pkrvars.hcl
   talos_version = "<TALOS_VERSION>" # e.g., "v1.7.0"
   image_url_arm = "https://factory.talos.dev/image/<SCHEMATIC_ID>/<TALOS_VERSION>/hcloud-arm64.raw.xz"
   image_url_x86 = "https://factory.talos.dev/image/<SCHEMATIC_ID>/<TALOS_VERSION>/hcloud-amd64.raw.xz"
   ```

   Replace the placeholders with your actual schematic ID and Talos version. Remember to also set the `talos_version` variable in this file, as recommended in the tip at the beginning of this document.

5. **Build the Images:**
   Run the `create.sh` script as usual:

   ```bash
   ./create.sh
   ```

   Packer will automatically pick up the variables from `hcloud.auto.pkrvars.hcl` and use your custom image URLs instead of the defaults.

## Image Labels

Images are created with the following labels for selection in Terraform:

| Label     | Description                      | Values                    |
|-----------|----------------------------------|---------------------------|
| `os`      | Operating system                 | `talos`                   |
| `arch`    | CPU architecture                 | `arm`, `x86`              |
| `version` | Talos version                    | e.g., `v1.11.0`           |
| `role`    | Node role (only with `--roles`)  | `control-plane`, `worker` |
| `creator` | Image creator                    | `hcloud-talos`            |
| `type`    | Resource type                    | `infra`                   |
