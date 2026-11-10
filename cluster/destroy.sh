#!/usr/bin/env bash
# Uso: bash cluster/destroy.sh   (valores en ../cluster.env)
set -Eeuo pipefail

CLUSTER_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${CLUSTER_DIR}/../cluster.env"
sudo --preserve-env=HOME talosctl cluster destroy --name "$CLUSTER_NAME"
rm -f "${HOME}/.talos/${CLUSTER_NAME}" "${HOME}/.kube/${CLUSTER_NAME}"
