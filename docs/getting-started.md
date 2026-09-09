# First installation: a fresh Mac host

This guide takes a freshly reset Apple silicon Mac from its initial macOS
account to the first GitHub Actions job. It is the end-to-end order for a new
installation; the individual component guides remain the detailed reference:

- [guest image](../guest/README.md)
- [host service](../host/README.md)
- [registry](../registry/README.md)
- [reusable workflow](./reusable-workflow.md)

The physical Mac is the **host**. It creates one disposable **job VM** from the
versioned **runner image** for each GitHub Actions job. The GitHub runner itself
runs inside that job VM, not on the host.

## 0. Choose the image source

Choose one path before configuring the host:

- **Local image**: a Tart image named `runner` already exists on the host. No
  registry, image tag, or digest is needed.
- **Remote image**: the image is stored in the OCI registry. The host needs the
  registry URL, image name, and the immutable manifest digest.

If no verified `runner` image exists yet, build it first in the next section.
The image can be built on another Mac; Packer is not required on the host when
the image is already available locally or in the registry.

## 1. Build and verify the runner image

Run this section on the Mac that will build the image (the host can also be that
Mac). On a freshly reset builder, install Homebrew and initialize its shell
environment before using `brew`:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install wget jq cirruslabs/cli/tart
brew tap hashicorp/tap
brew install hashicorp/tap/packer
cd guest
packer init base.pkr.hcl
packer build base.pkr.hcl
packer build runner.pkr.hcl
```

The `runner` image contains the GitHub Actions runner, Android tooling, asdf,
Node.js 22/24, Java 17/21, Ruby 3.3.6/3.4.6/4.0.6, and the Xcode path contract.
Xcode still requires an Apple ID and 2FA, so install and name both supported
applications manually inside the `runner` VM:

```sh
tart run runner
```

In the VM's Terminal, run:

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

In the VM terminal, verify the image before publishing or using it:

```sh
for version in 26 27; do
  test -d "/Applications/Xcode_${version}.app/Contents/Developer"
done
cat /etc/dromeis/toolchains.env
```

Exit the VM terminal, then stop it from the builder host before publishing:

```sh
tart stop runner
```

## 2. Publish the image (remote path only)

If you run the bundled Gitea registry, complete the
[registry setup](../registry/README.md) first. Its public hostname/IP, TLS
certificate SAN, and Gitea `ROOT_URL` must refer to the same registry host.
Create the registry account or access token there and keep its password outside
Git.

Choose a unique tag before pushing. The tag is only a temporary publishing
label; it is not what the host will consume.

```sh
REGISTRY_HOST=registry.example.com
REGISTRY_IMAGE_NAME=runner
IMAGE_TAG=runner-20260909-1430

tart login "$REGISTRY_HOST"
tart push runner "$REGISTRY_HOST/$REGISTRY_IMAGE_NAME:$IMAGE_TAG"
```

After the push, ask the registry for the manifest digest. The registry creates
this value; you do not invent it. Copy the returned
`Docker-Content-Digest: sha256:<64 hex characters>` value. It can be read in the
registry UI or through the OCI registry API. For a private Gitea registry, the
API shape is:

```sh
# Tart image references use the registry host without https://.
REGISTRY_HOST=registry.example.com
REGISTRY_API_URL="https://$REGISTRY_HOST"
# The repository path after the registry host, for example dromeis/runner.
REGISTRY_REPOSITORY=runner
REGISTRY_USERNAME=...
REGISTRY_PASSWORD=...
IMAGE_TAG=runner-20260909-1430

AUTH=$(printf '%s:%s' "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" | base64)
TOKEN=$(curl -fsS \
  -H "Authorization: Basic $AUTH" \
  "$REGISTRY_API_URL/v2/token?service=container_registry&scope=*" |
  jq -r '.token')
DIGEST=$(curl -fsS -D - -o /dev/null \
  -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
  -H "Authorization: Bearer $TOKEN" \
  "$REGISTRY_API_URL/v2/$REGISTRY_REPOSITORY/manifests/$IMAGE_TAG" |
  awk -F': ' 'tolower($1) == "docker-content-digest" { print $2; exit }' |
  tr -d '\r')
printf 'REGISTRY_IMAGE_DIGEST=%s\n' "$DIGEST"
```

Keep the digest for the host configuration. Do not replace it with the tag or
with `latest`.

## 3. Prepare the freshly reset Mac host

During macOS setup, use an administrator account with the short name `admin`.
The checked-in launchd plist currently uses `/Users/admin/vm` and runs the
service as `admin`. If the account already has another short name, either create
a dedicated `admin` account or update every matching path and username in the
plist before installing it.

On the host, configure:

- Apple silicon (`arm64`) hardware;
- **Remote Login** for administration;
- **Screen Sharing** if you need GUI access (optional for the service);
- a stable computer name and hostname;
- no automatic sleep while the display is off;
- automatic startup after a power failure.

Check the account and architecture:

```sh
id -un
uname -m
```

The second command must print `arm64`. Create the directory expected by the
plist:

```sh
mkdir -p /Users/admin/vm
```

## 4. Install host dependencies and copy the service

Install the tools on the host:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install wget cirruslabs/cli/tart cirruslabs/cli/sshpass
tart --version
sshpass -V
```

Create `.env` from [host/.env.example](../host/.env.example), remove the unused
organization/repository alternative, and keep exactly one active
`GITHUB_REGISTRATION_ENDPOINT` and one matching `RUNNER_URL`.

For a repository-scoped runner with a local image:

```dotenv
GITHUB_API_TOKEN=<token-with-runner-registration-permission>
GITHUB_REGISTRATION_ENDPOINT=https://api.github.com/repos/<ORG>/<REPO>/actions/runners/registration-token

VM_USERNAME=runner
VM_PASSWORD=runner
RUNNER_LABELS=self-hosted,arm64,dromeis
RUNNER_URL=https://github.com/<ORG>/<REPO>
RUNNER_NAME=dromeis-runner

REGISTRY_URL=
REGISTRY_IMAGE_NAME=runner
REGISTRY_IMAGE_DIGEST=

TRUNCATE_SIZE=200g
VM_RAM=8192
```

For a remote image, fill `REGISTRY_URL` with the registry host (without
`https://`) and add the digest obtained in section 2. Authenticate the host with
`tart login "$REGISTRY_URL"` before the first pull. Keep `.env` untracked and
readable only by the deployment user.

Create the local file from the example, remove the unused
organization/repository alternative, and edit it with the real values:

```sh
cp host/.env.example host/.env
$EDITOR host/.env
```

Copy the service files from the repository root. When copying over SSH, create
the destination first as shown in the previous section:

```sh
scp host/launch.sh host/com.dromeis.plist host/.env \
  admin@<HOST_IP>:/Users/admin/vm/
ssh admin@<HOST_IP> 'chmod 600 /Users/admin/vm/.env'
```

Use a unique `RUNNER_NAME` for each physical host. The default labels must stay
`self-hosted,arm64,dromeis` so they match the reusable workflow.

The current service uses the `runner`/`runner` account inside disposable VMs for
SSH bootstrap. The physical host account remains `admin`; the two accounts are
intentionally different. The SSH key mentioned in the guest guide is useful for
manual VM access, but the service currently authenticates with `sshpass`.

## 5. Run one job manually before launchd

Run these checks on the host:

```sh
cd /Users/admin/vm
chmod 755 launch.sh
bash -n launch.sh
```

For a local image, confirm that Tart can see it:

```sh
tart list | grep -F -- runner
```

For a remote image, test the immutable reference explicitly:

```sh
set -a
source .env
set +a
tart login "$REGISTRY_URL"
tart pull \
  "$REGISTRY_URL/$REGISTRY_IMAGE_NAME@$REGISTRY_IMAGE_DIGEST" \
  --concurrency 1
```

Start the loop in the foreground:

```sh
./launch.sh
```

Trigger a small validation job from a consuming repository using
`runs-on: [self-hosted, arm64, dromeis]`. Watch `runner.log` and confirm that a
job VM is created, the job runs, and the VM is stopped and deleted afterwards.
Stop the foreground process with `Ctrl-C`; its cleanup trap removes an active
VM.

## 6. Install the launchd service

Only after the manual cycle succeeds, install the persistent service:

```sh
cd /Users/admin/vm
chmod 755 launch.sh
sudo chown root:wheel launch.sh
sudo cp com.dromeis.plist /Library/LaunchDaemons/com.dromeis.plist
sudo launchctl load -w /Library/LaunchDaemons/com.dromeis.plist
sudo launchctl print system/com.dromeis
```

Logs are written beside the deployment files:

```sh
tail -f /Users/admin/vm/stdout /Users/admin/vm/stderr /Users/admin/vm/runner.log
```

To stop the service while diagnosing a problem:

```sh
sudo launchctl unload /Library/LaunchDaemons/com.dromeis.plist
```

## 7. Connect a React Native repository

The consuming project owns its caller workflow, event policy, tests, Fastlane
commands, and publication decisions. It can call the reusable Dromeis workflow
with a reviewed commit SHA and a project-owned command; see
[Reusable Dromeis workflow](./reusable-workflow.md).

Do not put App Store Connect or Match credentials in the image or the host
`.env`. Pass them explicitly from the consuming repository or organization only
for the publication job.

## Installation is complete when

- launchd reports `com.dromeis` as running;
- a GitHub job selects the `self-hosted`, `arm64`, and `dromeis` labels;
- each job gets a fresh disposable job VM;
- the job can use the installed toolchains and Xcode;
- the completed VM is removed after success, failure, or cancellation when the
  host process receives the termination signal.

Monitoring is optional for the first runner. Set it up later with the
[monitoring guide](../monitoring/README.md).
