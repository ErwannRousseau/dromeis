# Guest image provisioning

The guest scope builds the Tart macOS images that the host launches as ephemeral
GitHub Actions runners.

## ARCHITECTURE

- Build `base.pkr.hcl` before `runner.pkr.hcl`; the runner template clones the
  `base` VM.
- Treat Tart VM and registry state as external artifacts; this scope versions
  only the Packer templates and their documentation.

## CONVENTIONS

- Treat the base image as disposable runner infrastructure: its provisioning
  intentionally enables passwordless sudo and auto-login and disables sleep,
  locking, and Spotlight.
- Keep Xcode installation as the documented manual step because Apple two-factor
  authentication prevents the automated provisioner from completing it. Name the
  applications `/Applications/Xcode_<version>.app`.
- The host script connects to the guest's `runner` SSH account with password
  `runner`; the physical host account is independent.
- The image inventory is explicit and installed at build time; publish
  `/etc/dromeis/toolchains.env` with the image.

## NOTES

- Runner provisioning downloads the current GitHub Actions runner release and
  Homebrew packages at build time, so image contents depend on the network and
  are not lockfile-pinned. Toolchain versions themselves are explicit and jobs
  must not install missing versions.

## VALIDATION

- When the base template changes, rebuild `base` before rebuilding `runner`; use
  `guest/README.md` for the exact Packer commands.
