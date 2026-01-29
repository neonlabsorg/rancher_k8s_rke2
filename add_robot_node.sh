#!/usr/bin/env bash
set -euo pipefail

# ─── USER CONFIGURE ────────────────────────────────────────────────────────────
NEW_HOSTNAME="k8s-prod-rke2-robot-action-runner-0" # must be the same as in Hetzner Robot
RANCHER_SERVER_URL="https://rancher.neoninfra.xyz"
RANCHER_CLUSTER_REGISTRATION_TOKEN=""

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

# 2) IP Detection (for vSwitch/Private Network)
echo "→ Detecting IPs..."
# This should match your hcloud_network.rke2_network.ip_range
RKE2_NETWORK_RANGE="10.0.0.0/16" 
TARGET_ADDR=$(echo $RKE2_NETWORK_RANGE | cut -d'/' -f1)

PRIVATE_IP=$(ip route get $TARGET_ADDR | grep -oP 'src \K\S+' || true)
PUBLIC_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' || true)

if [[ -z "$PRIVATE_IP" || -z "$PUBLIC_IP" ]]; then
  echo "✖ Error: Could not detect IPs. Check network/vSwitch configuration."
  exit 1
fi
echo "→ Internal IP: $PRIVATE_IP, External IP: $PUBLIC_IP"

# 3) Create RKE2 config file manually (The most reliable way)
echo "→ Creating RKE2 configuration file..."
mkdir -p /etc/rancher/rke2/config.yaml.d/
cat <<EOF > /etc/rancher/rke2/config.yaml.d/99-node-ip.yaml
node-ip: "$PRIVATE_IP"
node-external-ip: "$PUBLIC_IP"
# tls-san is technically ignored for worker-only nodes, 
# but kept here for consistency or if the node is later promoted to control-plane
tls-san:
  - "$PRIVATE_IP"
  - "$PUBLIC_IP"
EOF

# 4) Forming the list of arguments for system-agent-install.sh
AGENT_ARGS=(
  "--server" "${RANCHER_SERVER_URL}"
  "--token" "${RANCHER_CLUSTER_REGISTRATION_TOKEN}"
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

# 5) Run
echo "→ Running Rancher System Agent installer..."
curl -fL "${RANCHER_SERVER_URL}/system-agent-install.sh" | sudo sh -s - "${AGENT_ARGS[@]}"

echo "→ Done. Check status: systemctl status rancher-system-agent"