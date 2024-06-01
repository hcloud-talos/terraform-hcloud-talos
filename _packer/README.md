# Add Extension to tho Talos Image

You can use the image factory to achieve this. The image factory is a tool that allows you to create custom Talos
images. You can find the documentation [here](https://www.talos.dev/v1.6/learn-more/image-factory/).

You can also use the endpoint to generate images. To achieve this, you need to adjust the `schematic.yaml` file to
include the extension you want to add to the image and then run the following command:

```shell
curl -X POST --data-binary @schematic.yaml https://factory.talos.dev/schematics
```

Then you can use the ID and the current Talos Version to get the image URLs with extensions:

- `https://factory.talos.dev/image/<ID>/<VERSION>/hcloud-amd64.raw.xz`.
- `https://factory.talos.dev/image/<ID>/<VERSION>/hcloud-arm64.raw.xz`.

Use these URLs in the `talos-hcloud.pkr.hcl` and replace `image_arm` and `image_x86` to create the snapshots with the
extensions.

You can create a file `hcloud.auto.pkrvars.hcl` to overwrite the default values. The file should look like this:
```hcl
talos_version = "v1.7.4"
image_url_arm = "https://factory.talos.dev/image/98b430833db447e791fa9fecb915073eb8a6d85ccf80ca3f67cd3bf56c527f49/v1.7.4/hcloud-arm64.raw.xz"
image_url_x86 = "https://factory.talos.dev/image/98b430833db447e791fa9fecb915073eb8a6d85ccf80ca3f67cd3bf56c527f49/v1.7.4/hcloud-amd64.raw.xz"
```
