# OCI image registry

The registry scope deploys Gitea as the HTTPS OCI registry consumed by Tart image pulls and pushes.

## ARCHITECTURE

- Keep the external registry URL, the certificate IP SAN, and `GITEA__server__ROOT_URL` synchronized; changing one without the others breaks TLS or image access.
- Keep registry runtime state outside Git; `auth/`, `certs/`, and `data/` are deployment-owned directories.

## CONVENTIONS

- Treat `tag.sh` as a local operator helper for registry manifest GET/PUT calls, not as reusable credential configuration.
- Do not replace the tracked registry placeholders with real usernames, passwords, private keys, or deployment secrets.

## VALIDATION

- Run `docker-compose -f registry/docker-compose.yaml config` after changing the registry Compose definition.
