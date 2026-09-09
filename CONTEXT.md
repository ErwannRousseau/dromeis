# Dromeis

Dromeis provisions disposable arm64 macOS GitHub Actions runners for mobile
projects. It owns the runner infrastructure and execution environment while each
consuming project owns the command used to validate or publish its application.

## Runner infrastructure

**Host**: The physical Apple silicon Mac that runs the Dromeis launch loop and
creates job VMs. _Avoid_: server, runner host

**Runner image**: A versioned Tart VM image containing the GitHub Actions runner
and the supported toolchain versions. _Avoid_: template, job VM

**Job VM**: A disposable VM cloned from the runner image for one GitHub Actions
runner job and removed after that job ends. _Avoid_: persistent VM, shared VM

**Dromeis runner**: The ephemeral self-hosted GitHub Actions runner configured
inside a job VM. _Avoid_: host runner, permanent runner

## Workflow boundary

**Caller workflow**: The minimal workflow stored in a consuming React Native
repository that reacts to repository events and calls Dromeis. _Avoid_: client
pipeline, application runner

**Dromeis workflow**: The reusable workflow stored in Dromeis that defines the
execution contract for caller workflows. _Avoid_: app workflow, build script

**Project command**: A command versioned in the consuming repository, such as a
script, `make`, `task`, Fastlane, or CocoaPods command, that Dromeis executes
after checkout. _Avoid_: Dromeis command, host command

**PR checkout**: The working tree at the exact `pull_request.head.sha` supplied
by the pull request event. _Avoid_: merge checkout, default checkout

## Toolchain versions

**Project version file**: A repository-controlled version declaration: `.nvmrc`
for Node.js, or `.tool-versions`, `.java-version`, and `.ruby-version` for Java
and Ruby. _Avoid_: image configuration

**Image default**: The default Xcode, Node.js, Java, or Ruby version configured
in the runner image when the project supplies no version and the workflow
supplies no input. Node.js defaults to 24.20.0, the latest LTS at this decision;
Java defaults to 17 for React Native compatibility; Ruby defaults to 4.0.6, the
latest stable release because Ruby has no LTS channel. The selected versions are
pinned when the image is built. _Avoid_: host default, live version lookup

**Version resolution**: The selection policy
`project version file > workflow input > image default`, applied independently
to each supported toolchain. Version declarations use exact versions; aliases,
ranges, and automatic downloads are not part of the contract. _Avoid_: version
fallback

**Xcode installation**: The image stores selectable Xcode applications as
`/Applications/Xcode_<version>.app`; `xcode-version` addresses one exact
application and no input leaves the image-selected default in place. _Avoid_:
latest Xcode, implicit Xcode download

**Unavailable version**: A resolved version that is not installed in the runner
image; it is a workflow error and the project command is not started. _Avoid_:
auto-installed version, best-effort version

## Publication

**TestFlight publication**: The signed iOS build upload to App Store Connect
initiated by a project command. _Avoid_: Dromeis release, App Store deployment

**Application signing secrets**: Repository- or organization-scoped credentials
passed explicitly to the Dromeis workflow for publication and kept out of the
runner image and host configuration. _Avoid_: image secrets, host signing
credentials
