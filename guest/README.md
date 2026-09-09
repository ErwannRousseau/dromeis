# Guest Configuration

The templates for this projet were adapted from the
[cirruslab templates](https://github.com/cirruslabs/macos-image-templates).

## Prerequisite

Make sure you have both `tart` and `packer` installed

```sh
brew install cirruslabs/cli/tart
brew tap hashicorp/tap
brew install hashicorp/tap/packer
```

## Create a base image

Run the following to creates a `base` VM in tart that can be used as a starting
point for the runner. The script should then complete the macOS setup on its
own.

```sh
packer init base.pkr.hcl
packer build base.pkr.hcl
```

By default, this will download the latest MacOS recovery image and configure a
VM from it. Alternatively, a URL or a path for the image to use can be
specified. Available recovery images can be found here: <https://ipsw.me/>

```
packer build base.pkr.hcl -var "ipsw=PATH_OR_URL_TO_IPSW"
```

## Create a runner image

Run the following to create a clone from `base` VM and configure it with the
necessary tools for a runner

```sh
packer build runner.pkr.hcl
```

## Install the Host's SSH Key

Install the host's public key on the VM. This will allow the host's script to
launch commands inside the VM.

```sh
tart run runner
ssh-copy-id -i SSH_KEY_FILE runner@$(tart ip runner)
```

## Install Xcode

Xcode cannot be installed automatically from the script as it requires a 2FA
with an Apple ID. It can be installed with
[xcodes](https://github.com/RobotsAndPencils/xcodes) from within the VM. Install
both supported versions manually and keep the exact application names used by
the workflow:

```sh
xcodes install 26 --experimental-unxip
sudo mv /Applications/Xcode-26*.app /Applications/Xcode_26.app
xcodes install 27 --experimental-unxip
sudo mv /Applications/Xcode-27*.app /Applications/Xcode_27.app
sudo xcode-select -s /Applications/Xcode_27.app
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -downloadAllPlatforms
```

Verify the image inventory before publishing it:

```sh
for version in 26 27; do
  test -d "/Applications/Xcode_${version}.app/Contents/Developer"
done
```

## Push the image on the container registry

The new image can be pushed to a registry to facilitate the distribution. Follow
the [registry configuration guide](registry/README.md) to get one running.
Replace `IMAGE_TAG` with a unique build identifier (for example, a release or
commit label). The tag is only a mutable name for publishing; it is not the
image reference used by the host.

```
tart login REGISTRY_URL
tart push runner REGISTRY_URL/runner:IMAGE_TAG
```

After publishing, read the pushed manifest's digest from the registry and set
`REGISTRY_IMAGE_DIGEST=sha256:<64_HEX_DIGEST>` in the host `.env`. For example,
the host turns `REGISTRY_URL/runner` plus that digest into
`REGISTRY_URL/runner@sha256:<64_HEX_DIGEST>` and pulls that immutable image. Do
not copy `IMAGE_TAG` into `REGISTRY_IMAGE_DIGEST` or use `latest`.

The image provisions Node.js 22.20.0 and 24.20.0 (default 24.20.0), Java 17 and
21 (default 17), and Ruby 3.3.6, 3.4.6, and 4.0.6 (default 4.0.6) at build time.
The inventory and defaults are written to `/etc/dromeis/toolchains.env`; jobs
must use those installed runtimes and must not download toolchains.
