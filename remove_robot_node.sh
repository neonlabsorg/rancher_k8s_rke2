#!/usr/bin/env bash
set -euo pipefail

# --------------------------
# Do this on the machine that have a connection to the cluster
# --------------------------
# Identify the worker node name
# kubectl get nodes

# Always drain the node first before deletion to safely evict pods
# kubectl drain #####WORKER_NODE_NAME##### --ignore-daemonsets --delete-emptydir-data
# kubectl delete node #####WORKER_NODE_NAME#####


if [[ $EUID -ne 0 ]]; then
  echo "✖ This script must be run as root: sudo $0"
  exit 1
fi

WORKER_NODE_NAME=$(hostname)
echo "--- STARTING RKE2 NODE CLEANUP: ${WORKER_NODE_NAME} ---"


# --- STEP 1: Stop the RKE2 Services ---
echo "→ Step 1: Stopping RKE2 agent services..."
systemctl stop rke2-agent 2>/dev/null || true
systemctl disable rke2-agent 2>/dev/null || true


# --- STEP 2: Run the Uninstall Script ---
echo "→ Step 3: Running the official RKE2 uninstall script..."
if [ -f /usr/local/bin/rke2-uninstall.sh ]; then
    sudo /usr/local/bin/rke2-uninstall.sh
else
    echo "⚠ /usr/local/bin/rke2-uninstall.sh not found. Skipping."
fi


# --- STEP 3: Remove Any Remaining Files ---
echo "→ Step 4: Cleaning up remaining files and directories..."
REMAINING_FILES=(
    "/etc/rancher/rke2"
    "/var/lib/rancher"
    "/var/lib/kubelet"
    "/etc/systemd/system/rke2*"
    "/usr/local/lib/systemd/system/rke2*"
    "/usr/local/bin/rke2*"
    "/var/lib/cni/"
    "/etc/cni/"
    "/var/lib/containerd/"
    "/run/k3s/"
    "/var/lib/rancher-data/"
    "/usr/bin/rke2*"
)

for item in "${REMAINING_FILES[@]}"; do
    rm -rf ${item}
    echo "  [removed] ${item}"
done


# --- STEP 4: Verify Removal ---
echo "→ Step 4: Verifying service removal..."
if ! systemctl list-unit-files | grep -q rke2-agent; then
    echo "✓ RKE2 Agent service successfully removed."
else
    echo "⚠ RKE2 Agent service still exists."
fi

echo "--- CLEANUP COMPLETE ---"