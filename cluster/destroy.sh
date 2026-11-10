#!/usr/bin/env bash
# Uso: bash cluster/destroy.sh   (valores en ../cluster.env)
set -Eeuo pipefail

CLUSTER_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${CLUSTER_DIR}/../cluster.env"
sudo --preserve-env=HOME talosctl cluster destroy --name "$CLUSTER_NAME"
rm -f "${HOME}/.talos/${CLUSTER_NAME}" "${HOME}/.kube/${CLUSTER_NAME}"

# create agrega el clúster a ~/.kube/config (admin@<nombre>, o admin@<nombre>-N si ya existía) y destroy no lo quita
DEFAULT_KUBECONFIG="${HOME}/.kube/config"
if [ -f "$DEFAULT_KUBECONFIG" ]; then
  current="$(kubectl --kubeconfig "$DEFAULT_KUBECONFIG" config current-context 2>/dev/null || true)"
  for context in $(kubectl --kubeconfig "$DEFAULT_KUBECONFIG" config get-contexts -o name \
                   | grep -E "^admin@${CLUSTER_NAME}(-[0-9]+)?$" || true); do
    [ "$context" = "$current" ] && kubectl --kubeconfig "$DEFAULT_KUBECONFIG" config unset current-context
    kubectl --kubeconfig "$DEFAULT_KUBECONFIG" config delete-context "$context"
    kubectl --kubeconfig "$DEFAULT_KUBECONFIG" config delete-cluster "${context#admin@}"
    kubectl --kubeconfig "$DEFAULT_KUBECONFIG" config delete-user "$context"
  done
fi
