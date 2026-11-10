#!/usr/bin/env bash
# Uso: bash cluster/create.sh   (sin sudo delante; lo pide solo para talosctl: QEMU necesita root para la red vmnet de macOS)
# Valores en ../cluster.env
set -Eeuo pipefail

CLUSTER_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${CLUSTER_DIR}/../cluster.env"
# talosctl deja .1 para la Mac y reparte desde .2, primero los control planes
CONTROLPLANE_IP="${CIDR%.*}.2"
export TALOSCONFIG="${HOME}/.talos/${CLUSTER_NAME}"
export KUBECONFIG="${HOME}/.kube/${CLUSTER_NAME}"

mkdir -p "${HOME}/.talos/clusters" "${HOME}/.kube"
# talosctl deja controlplane.yaml y worker.yaml en el directorio actual: que no caigan en el repo
WORK_DIR="$(mktemp -d)"
trap 'sudo rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"
sudo --preserve-env=HOME talosctl cluster create qemu \
  --name "$CLUSTER_NAME" \
  --talos-version "$TALOS_VERSION" \
  --kubernetes-version "$KUBERNETES_VERSION" \
  --cidr "$CIDR" \
  --controlplanes "$CONTROLPLANES" --workers "$WORKERS" \
  --cpus-controlplanes "$CONTROLPLANE_CPUS" --cpus-workers "$WORKER_CPUS" \
  --memory-controlplanes "$CONTROLPLANE_MEMORY" --memory-workers "$WORKER_MEMORY" \
  --disks "virtio:${SYSTEM_DISK},virtio:${WORKER_DATA_DISK}" \
  --config-patch "@${CLUSTER_DIR}/patches/common.yaml" \
  --config-patch-workers "@${CLUSTER_DIR}/patches/worker.yaml" \
  --talosconfig-destination "$TALOSCONFIG"
sudo chown "$(id -u):$(id -g)" "$TALOSCONFIG"
talosctl -n "$CONTROLPLANE_IP" kubeconfig "$KUBECONFIG" --force

# /opt es de solo lectura en Talos: local-path usa el volumen de patches/worker.yaml
curl -fsSL "https://raw.githubusercontent.com/rancher/local-path-provisioner/${LOCAL_PATH_VERSION}/deploy/local-path-storage.yaml" \
  | sed 's#/opt/local-path-provisioner#/var/mnt/local-path-provisioner#' \
  | kubectl apply -f -
kubectl label namespace local-path-storage pod-security.kubernetes.io/enforce=privileged --overwrite
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo "==> Cluster ${CLUSTER_NAME} ready. talosconfig: ${TALOSCONFIG} · kubeconfig: ${KUBECONFIG}"
