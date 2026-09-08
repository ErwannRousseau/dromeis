# Ekiden runner infrastructure

This repository provisions and operates ephemeral arm64 macOS GitHub Actions
runners with Tart, Packer, Gitea, and Grafana.

## ARCHITECTURE

- Keep host, guest, registry, and monitoring changes in their own boundary, and
  update their cross-boundary contracts together.

## WHERE TO LOOK

- For host launchd deployment, VM lifecycle, and runner configuration, read
  `host/README.md`.
- For Tart image layering, manual Xcode setup, and image publication, read
  `guest/README.md`.
- For the Gitea OCI registry and certificate setup, read `registry/README.md`.
- For log collection and Grafana deployment, read `monitoring/README.md`.

## CONVENTIONS

- Keep deployment secrets, `.env`, logs, registry `auth/`, `certs/`, `data/`,
  and private keys out of Git; treat committed bootstrap and placeholder
  credentials as disposable defaults, not production secrets.
- Use the `Makefile` and `.github/workflows/ci.yaml` as the validation source of
  truth; this repository has no application package or workspace manifest.

## VALIDATION

- Run `make lint`; CI uses it as the repository gate for Prettier, shfmt, and
  ShellCheck.

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues; use the `gh` CLI. See
`docs/agents/issue-tracker.md`.

### Triage labels

Use the five canonical triage labels unchanged: `needs-triage`, `needs-info`,
`ready-for-agent`, `ready-for-human`, and `wontfix`. See
`docs/agents/triage-labels.md`.

### Domain docs

Use the single-context layout with root `CONTEXT.md` and `docs/adr/`. See
`docs/agents/domain.md`.
