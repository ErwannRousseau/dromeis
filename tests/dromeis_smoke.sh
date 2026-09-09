#!/bin/bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

assert_contains() {
	local file=$1
	local expected=$2
	grep -F -- "$expected" "$file" >/dev/null || {
		echo "Missing '$expected' in $file" >&2
		exit 1
	}
}

assert_not_contains() {
	local file=$1
	local unexpected=$2
	if grep -F -- "$unexpected" "$file" >/dev/null; then
		echo "Unexpected '$unexpected' in $file" >&2
		exit 1
	fi
}

workflow=.github/workflows/dromeis.yaml
docs=docs/reusable-workflow.md
image=guest/runner.pkr.hcl
host=host/launch.sh

assert_contains "$workflow" 'workflow_call:'
assert_contains "$workflow" 'runs-on: [self-hosted, arm64, dromeis]'
assert_contains "$workflow" "ref: \${{ github.event.pull_request.head.sha }}"
assert_contains "$workflow" 'source /etc/dromeis/toolchains.env'
assert_contains "$workflow" 'bash --noprofile --norc -Eeuo pipefail {0}'
assert_contains "$workflow" 'APP_STORE_CONNECT_PRIVATE_KEY'
assert_contains "$workflow" 'choose_version NODE_VERSION'
assert_contains "$workflow" 'choose_version JAVA_VERSION'
assert_contains "$workflow" 'choose_version RUBY_VERSION'
assert_contains "$workflow" 'choose_version XCODE_VERSION'
assert_contains "$workflow" 'java_asdf_requested'
assert_not_contains "$workflow" 'asdf.sh'

assert_contains "$docs" "\`pull_request\` types \`opened\`, \`synchronize\`,"
assert_contains "$docs" "and \`reopened\` for validation."
assert_contains "$docs" "github.event.label.name == 'testflight'"
assert_contains "$docs" 'Do not publish'
assert_contains "$docs" "on \`synchronize\`, even when the pull request already has the label."
assert_contains "$docs" 'Xcode_<version>.app'

assert_contains "$image" 'DROMEIS_NODE_VERSIONS=20.19.4,22.20.0,24.20.0'
assert_contains "$image" 'brew install wget cmake gcc git-lfs jq unzip zip ca-certificates awscli gpg gawk'
assert_contains "$image" 'DROMEIS_JAVA_VERSIONS=11,17,21'
assert_contains "$image" 'DROMEIS_RUBY_VERSIONS=3.3.6,3.4.6,4.0.6'
assert_contains "$image" 'DROMEIS_XCODE_VERSIONS=26,27'
assert_not_contains "$image" 'asdf.sh'

assert_contains "$host" 'RUNNER_LABELS="self-hosted,arm64,dromeis"'
assert_contains "$host" 'trap cleanup EXIT SIGINT SIGTERM'
assert_contains "$host" 'REGISTRY_IMAGE_DIGEST='
assert_contains "$host" "tart ip \"\$INSTANCE_NAME\" 2>/dev/null || true"
assert_contains "$host" "if [ -f \"\$HOME/.ssh/known_hosts\" ]; then"

bash -n "$host"

echo 'Dromeis workflow smoke checks passed'
