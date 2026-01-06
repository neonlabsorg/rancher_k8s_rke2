#!/usr/bin/env bash
set -euo pipefail

# ─── USER CONFIGURE ────────────────────────────────────────────────────────────
NEW_HOSTNAME="k8s-prod-rke2-robot-action-runner-0" # must be the same as in Hetzner Robot
RANCHER_SERVER_URL="https://rancher.neoninfra.xyz"
RANCHER_TOKEN="2szzcd9wznf2pqxhckrrn8p9vq747qdlbh5xwkpm4kwrw8tjfvndsz"

# Labels and Taints
LABELS=( "workload=runners" )
TAINTS=( "runners=true:NoSchedule" "hcloudRobot=true:NoSchedule" )
# ────────────────────────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  echo "✖ Please run as root"
  exit 1
fi

# 1) Setting hostname
echo "→ Setting hostname to: ${NEW_HOSTNAME}"
hostnamectl set-hostname "${NEW_HOSTNAME}"

# 2) Forming the list of arguments for system-agent-install.sh
# We pass them as an array, so spaces and special characters don't float
AGENT_ARGS=(
  "--server" "${RANCHER_SERVER_URL}"
  "--token" "${RANCHER_TOKEN}"
  "--node-name" "${NEW_HOSTNAME}"
  "--worker"
  "--label" "cattle.io/os=linux"
)

# Add labels (each label goes as a pair: --label key=value)
for lbl in "${LABELS[@]}"; do
  AGENT_ARGS+=( "--label" "${lbl}" )
done

# Add taints (through --taint, as in your code)
for t in "${TAINTS[@]}"; do
  AGENT_ARGS+=( "--taint" "${t}" )
done

# 3) Run
echo "→ Running Rancher System Agent installer with args: ${AGENT_ARGS[*]}"

# Important: use "${AGENT_ARGS[@]}" in quotes to preserve the array structure
curl -fL "${RANCHER_SERVER_URL}/system-agent-install.sh" | sudo sh -s - "${AGENT_ARGS[@]}"

echo "→ Done. Check status: systemctl status rancher-system-agent"