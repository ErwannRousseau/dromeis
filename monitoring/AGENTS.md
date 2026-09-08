# Runner monitoring stack

The monitoring scope deploys Grafana, Loki, and Promtail on a host and collects
runner logs from the host VM directory.

## ARCHITECTURE

- Keep `HOST_URL` consistent between `docker-compose.yaml` and
  `promtail/config.yaml`, and update the Promtail machine label for each host.
- Keep the Promtail `/Users/admin/vm` bind mount aligned with the host launch
  directory and its `*.log` output.
- Keep the launch script and LaunchDaemon paths aligned with
  `/Users/admin/grafana` and the Homebrew installation at
  `/opt/homebrew/bin/brew`.

## ANTI-PATTERNS

- Do not treat the default stack as a secure public service: the documented
  setup uses HTTP, disables Loki authentication, and explicitly has no security
  controls.

## VALIDATION

- Run `docker-compose -f monitoring/docker-compose.yaml config` after changing
  the monitoring Compose definition.
