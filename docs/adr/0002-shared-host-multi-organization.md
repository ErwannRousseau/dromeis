# Shared Host for multiple client organizations

Use one physical Host for multiple independent client organizations, with one
isolated organization runner service per organization. Each service owns its
GitHub credentials, endpoint, URL, runner identity, working directory, Tart
cache, logs, and launchd lifecycle; concurrent jobs receive distinct runner
names and disposable Job VMs. Services may share the same immutable runner image
digest, but the Host enforces global and per-organization concurrency limits.
Client organizations provide and revoke their least-privilege tokens, and public
or untrusted repositories require a dedicated Host.

This avoids a central multi-tenant dispatcher while retaining client isolation.
The initial 16-GB/8-CPU Host starts with one full-size RN/Xcode Job VM and can
raise the limit only after benchmarking; reliable concurrency for multiple heavy
builds may require more RAM. Image rollouts are staged, and each service must
restart independently after a Host reboot or service failure.
