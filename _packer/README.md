# Build Talos Images for Hetzner Cloud

This directory contains Packer configuration to build Talos OS images suitable for use with Hetzner Cloud.

> [!TIP]
> It's good practice to **always** create a `_packer/hcloud.auto.pkrvars.hcl` file to explicitly set the `talos_version`. This ensures the Packer build uses the exact Talos version you intend to deploy with Terraform, preventing potential mismatches if the default value in `talos-hcloud.pkr.hcl` is outdated or if you are using custom images from the Image Factory.
> Your `hcloud.auto.pkrvars.hcl` would simply contain:
> ```hcl
> # _packer/hcloud.auto.pkrvars.hcl
> talos_version = "v1.7.0" # Replace with your desired Talos version
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

## Advanced Usage: Adding Extensions to the Talos Image

If you need to include additional system extensions in your Talos images (e.g., for specific storage drivers or tools), you can use the Talos Image Factory.

1.  **Define Extensions:**
    Adjust the `schematic.yaml` file to include the official or custom extensions you need. The current file includes examples for `iscsi-tools`, `util-linux-tools`, and `binfmt-misc`.

2.  **Generate Schematic ID:**
    Use the Talos Image Factory endpoint to generate a unique ID for your schematic configuration:

    ```shell
    curl -X POST --data-binary @schematic.yaml https://factory.talos.dev/schematics
    ```
    This command will return a JSON response containing the schematic ID.

3.  **Get Custom Image URLs:**
    Use the schematic ID and the desired Talos version to construct the URLs for the custom images:

    - ARM: `https://factory.talos.dev/image/<SCHEMATIC_ID>/<TALOS_VERSION>/hcloud-arm64.raw.xz`
    - x86: `https://factory.talos.dev/image/<SCHEMATIC_ID>/<TALOS_VERSION>/hcloud-amd64.raw.xz`

    Replace `<SCHEMATIC_ID>` with the ID obtained in the previous step and `<TALOS_VERSION>` with the target Talos version (e.g., `v1.7.0`).

4.  **Override Packer Variables:**
    Create a file named `hcloud.auto.pkrvars.hcl` in this directory to provide the custom image URLs and the corresponding Talos version to Packer. The file should look like this:

    ```hcl
    # _packer/hcloud.auto.pkrvars.hcl
    talos_version = "<TALOS_VERSION>" # e.g., "v1.7.0"
    image_url_arm = "https://factory.talos.dev/image/<SCHEMATIC_ID>/<TALOS_VERSION>/hcloud-arm64.raw.xz"
    image_url_x86 = "https://factory.talos.dev/image/<SCHEMATIC_ID>/<TALOS_VERSION>/hcloud-amd64.raw.xz"
    ```
    Replace the placeholders with your actual schematic ID and Talos version. Remember to also set the `talos_version` variable in this file, as recommended in the tip at the beginning of this document.

5.  **Build the Images:**
    Run the `create.sh` script as usual:
    ```bash
    ./create.sh
    ```
    Packer will automatically pick up the variables from `hcloud.auto.pkrvars.hcl` and use your custom image URLs instead of the defaults.
