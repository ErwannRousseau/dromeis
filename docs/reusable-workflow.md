# Reusable Dromeis workflow

Consuming repositories call `.github/workflows/dromeis.yaml` for a project-owned
validation or TestFlight command. The caller supplies the command and, when
needed, these optional inputs: `xcode-version`, `node-version`, `java-version`,
and `ruby-version`.

Publication credentials are passed explicitly from the consuming repository or
organization:

```yaml
jobs:
  validate:
    uses: ErwannRousseau/dromeis/.github/workflows/dromeis.yaml@<commit-sha>
    with:
      command: ./scripts/ci.sh
    secrets:
      APP_STORE_CONNECT_KEY_ID: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
      APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
      APP_STORE_CONNECT_PRIVATE_KEY:
        ${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY }}
      MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
```

The reusable workflow exposes these secrets to the project command as
environment variables with the same names. Validation callers can omit the
`secrets` mapping; publication callers should pass only the credentials they
need.

Runner images provide `/etc/dromeis/toolchains.env` with this shell-variable
contract (comma-separated exact versions):

```sh
DROMEIS_NODE_VERSIONS DROMEIS_NODE_DEFAULT
DROMEIS_JAVA_VERSIONS DROMEIS_JAVA_DEFAULT DROMEIS_JAVA_ASDF_VERSIONS
DROMEIS_RUBY_VERSIONS DROMEIS_RUBY_DEFAULT
DROMEIS_XCODE_VERSIONS DROMEIS_XCODE_DEFAULT
```

Node.js and Ruby are selected from their installed asdf paths. Java is selected
from an installed JDK, and Xcode uses `/Applications/Xcode_<version>.app`. Jobs
never download or install a missing version.

The caller owns event policy. Use `pull_request` types `opened`, `synchronize`,
and `reopened` for validation. Add a separate publication job for `pull_request`
`labeled`, guarded by `github.event.label.name == 'testflight'`. Do not publish
on `synchronize`, even when the pull request already has the label.

Pin the `uses` reference to a reviewed Dromeis commit SHA. The workflow checks
out `github.event.pull_request.head.sha`, resolves only versions already listed
in `/etc/dromeis/toolchains.env`, and runs the command from the checkout root.
Missing versions, aliases, and ranges fail before the command; the error
includes the requested and available versions.
