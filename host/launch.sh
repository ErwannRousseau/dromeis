#!/bin/bash
set -Eeuo pipefail

GITHUB_API_TOKEN=
GITHUB_REGISTRATION_ENDPOINT=

VM_USERNAME="runner"
VM_PASSWORD="runner"

RUNNER_LABELS="self-hosted,arm64,dromeis"
RUNNER_URL=
RUNNER_NAME="Runner"

REGISTRY_URL=
REGISTRY_IMAGE_NAME="runner"
REGISTRY_IMAGE_DIGEST=

LOGFILE="runner.log"
SCHEDULE_SHUTDOWN=false

function log_output {
	if [ -z "${2:-}" ] || [ "${2:-}" = "true" ]; then
		echo "$(date "+%Y/%m/%d %H:%M:%S") $1"
		echo "$(date "+%Y/%m/%d %H:%M:%S") [${RUN_ID:-PREPARING}] $1" >>$LOGFILE
	fi
}

function stream_output {
	while read -r line; do
		log_output "$line"
	done
}

function reload_env {
	if [ -f .env ]; then
		# shellcheck disable=SC2046
		export $(xargs <.env)
	fi
}

function cleanup_vm {
	if [ -n "${INSTANCE_NAME:-}" ]; then
		log_output "[HOST] ✋ Stop the VM"
		tart stop "$INSTANCE_NAME" >/dev/null 2>&1 || true
		log_output "[HOST] 🧹 Cleanup the VM"
		tart delete "$INSTANCE_NAME" >/dev/null 2>&1 || true
		INSTANCE_NAME=""
	fi
}

function cleanup {
	local status=$?
	trap - EXIT SIGINT SIGTERM
	cleanup_vm
	log_output "[HOST] 🚦 Stopping runner script"
	exit "$status"
}

function ssh_command() {
	local command=$1
	local show_output=${2:-}

	if [ -z "${show_output}" ] || [ "${show_output}" = "true" ]; then
		SSHPASS=$VM_PASSWORD sshpass -e ssh -q -o StrictHostKeyChecking=no "$VM_USERNAME@$IP_ADDRESS" "$command" 2>&1 | sed -nru 's/^(.+)$/[GUEST] 📀 \1/p' | stream_output
	else
		SSHPASS=$VM_PASSWORD sshpass -e ssh -q -o StrictHostKeyChecking=no "$VM_USERNAME@$IP_ADDRESS" "$command" >/dev/null
	fi
}

function boot_vm {
	BASE_IMAGE=$1
	INSTANCE_NAME=$2
	ENABLE_LOGGING=${3:-true}

	TART_NO_AUTO_PRUNE="" tart clone "$BASE_IMAGE" "$INSTANCE_NAME"
	trap cleanup EXIT SIGINT SIGTERM

	tart set "$INSTANCE_NAME" --memory "${VM_RAM:-8192}"
	tart set "$INSTANCE_NAME" --cpu "${VM_CPU:-4}"

	tart run --no-graphics "$INSTANCE_NAME" >/dev/null 2>&1 &

	log_output "[HOST] 💤 Waiting for VM to boot" "$ENABLE_LOGGING"
	IP_ADDRESS=""
	until [[ "$IP_ADDRESS" =~ ^([0-9]+\.){3}[0-9]+$ ]]; do
		IP_ADDRESS=$(tart ip "$INSTANCE_NAME" 2>/dev/null || true)
		[[ "$IP_ADDRESS" =~ ^([0-9]+\.){3}[0-9]+$ ]] || sleep 1
	done

	# Clean old SSH host key reference for the VM to avoid conflicts
	if [ -f "$HOME/.ssh/known_hosts" ]; then
		ssh-keygen -R "$IP_ADDRESS" >/dev/null
	fi

	log_output "[HOST] 💤 Waiting for SSH to be available on VM" "$ENABLE_LOGGING"
	until [ "$(SSHPASS=$VM_PASSWORD sshpass -e ssh -q -o ConnectTimeout=1 -o StrictHostKeyChecking=no "$VM_USERNAME@$IP_ADDRESS" pwd)" ]; do
		sleep 1
	done
}

function resize_cached_image {
	# The images from cirruslabs are too small for some builds
	# This step allows to resize the disk by truncating the disk file and booting the VM to resize the partition
	if [ -n "${TRUNCATE_SIZE:-}" ]; then
		log_output "[HOST] 📊 Resizing the disk at path '$REGISTRY_DISK_PATH' to $TRUNCATE_SIZE"
		truncate -s "$TRUNCATE_SIZE" "$REGISTRY_DISK_PATH/disk.img"

		log_output "[HOST] 📊 Booting instance"
		local INSTANCE_NAME="truncate_instance"
		boot_vm "$REGISTRY_PATH" "$INSTANCE_NAME" false

		log_output "[HOST] 📊 Repairing disk"
		ssh_command "echo y | diskutil repairDisk disk0"

		log_output "[HOST] 📊 Resizing partition"
		ssh_command "diskutil apfs resizeContainer disk0s2 0"

		log_output "[HOST] 📊 Stoping instance"
		tart stop $INSTANCE_NAME
		rm "$REGISTRY_DISK_PATH/disk.img"
		cp -c ~/.tart/vms/"$INSTANCE_NAME"/disk.img "$REGISTRY_DISK_PATH/"
		tart delete $INSTANCE_NAME
	fi
}

function pull_image {
	log_output "[HOST] 🗑️ Removing all old images"
	rm -rf ~/.tart

	log_output "[HOST] ⬇️ Downloading from remote registry"
	if [ -z "${REGISTRY_USERNAME:-}" ]; then
		tart pull "$REGISTRY_PATH" --concurrency 1
	else
		TART_REGISTRY_USERNAME="$REGISTRY_USERNAME" TART_REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}" tart pull "$REGISTRY_PATH" --concurrency 1
	fi

	resize_cached_image
}

function run_loop {
	RUN_ID="$RANDOM$RANDOM"

	log_output "[HOST] 🎫 Creating registration token"
	REGISTRATION_TOKEN=$(curl -s -XPOST -H "Authorization: bearer $GITHUB_API_TOKEN" -H "Accept: application/vnd.github.v3+json" "$GITHUB_REGISTRATION_ENDPOINT" | grep "token" | sed "s/..\"token\":.\"//" | sed "s/\",$//")

	log_output "[HOST] 💻 Launching macOS VM"
	INSTANCE_NAME=runner_"$RUNNER_NAME"_"$RUN_ID"
	boot_vm "$REGISTRY_PATH" "$INSTANCE_NAME"

	log_output "[HOST] 🔨 Configuring runner on VM"
	ssh_command "./actions-runner/config.sh --url $RUNNER_URL --token $REGISTRATION_TOKEN --ephemeral --name $RUNNER_NAME --labels $RUNNER_LABELS --unattended --replace" false

	log_output "[HOST] 🏃 Starting runner on VM"
	ssh_command "source ~/.zprofile && ./actions-runner/run.sh"

	cleanup_vm
	RUN_ID=""
}

# Configure Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# Show a shutdown message when closing the script
trap cleanup SIGINT SIGTERM

# Main loop
while :; do
	reload_env

	if [[ "$SCHEDULE_SHUTDOWN" == "true" ]]; then
		log_output "[HOST] ⏰ Scheduled for shutdown"
		cleanup
	fi

	# Select image
	if [ -n "${REGISTRY_URL}" ]; then
		if [[ "${REGISTRY_IMAGE_NAME}" == *latest* ]] || [[ ! "${REGISTRY_IMAGE_DIGEST:-}" =~ ^sha256:[0-9a-fA-F]{64}$ ]]; then
			log_output "[HOST] ❌ Remote images require a non-latest name and sha256 digest"
			exit 1
		fi
		REGISTRY_PATH="$REGISTRY_URL/$REGISTRY_IMAGE_NAME@$REGISTRY_IMAGE_DIGEST"
		REGISTRY_DISK_PATH="$HOME/.tart/cache/OCIs/${REGISTRY_PATH//://}"
	else
		REGISTRY_PATH="$REGISTRY_IMAGE_NAME"
	fi

	# Pull image if not cached
	if ! tart list | grep -F -- "$REGISTRY_PATH"; then
		log_output "[HOST] 🔎 Target image not found"
		if [ -n "${REGISTRY_URL}" ]; then
			pull_image
		else
			cleanup
		fi
	fi

	run_loop
done
