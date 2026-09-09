# Host runner lifecycle

The host scope runs the launchd-managed loop that creates one disposable Tart VM
for each GitHub Actions runner job.

## ARCHITECTURE

- Preserve the stop-and-delete lifecycle around every runner VM, including the
  signal traps used during boot and execution.
- Treat `pull_image` as a destructive cache refresh: when a registry is
  configured it removes `~/.tart` before pulling the image.
- Apply `VM_RAM` and `VM_CPU` before `tart run`; their script defaults are 8192
  MB and 4 CPUs.

## CONVENTIONS

- Keep `.env` and `runner.log` relative to the launchd working directory; the
  checked-in plist runs from `/Users/admin/vm` and expects the deployment files
  there.
- Keep secrets and host-specific runner or registry values in the untracked
  `.env`; update `host/.env.example` when adding a required setting without
  committing real values.
- Keep exactly one active GitHub endpoint and runner URL per deployment; the
  example lists organization and repository alternatives, and the loader applies
  the later duplicate value.
- Verify `VM_USERNAME` and `VM_PASSWORD` against the built guest image before
  launching; the current guest templates use `runner` while this host script
  defaults to `admin`.
