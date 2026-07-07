#!/usr/bin/env bash
###############################################################################
# Dispatcher de déploiement multi-cible pour personal-gen-ai
#
# Usage:
#   ./deploy.sh <aws|runpod> <up|down|status>
#
#   up      provisionne la stack (terraform apply)
#   down    détruit la stack     (terraform destroy)
#   status  affiche les sorties  (terraform output), dont l'URL HTTPS
#
# Prérequis:
#   - terraform >= 1.5.7
#   - cible aws    : aws-cli configuré (credentials)
#   - cible runpod : variable d'environnement RUNPOD_API_KEY
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 <aws|runpod> <up|down|status>" >&2
  exit 2
}

[ $# -eq 2 ] || usage
TARGET="$1"
ACTION="$2"

case "$TARGET" in
  aws|runpod|exoscale|vastai|ovhcloud) ;;
  *) echo "Cible inconnue: '$TARGET'" >&2; usage ;;
esac

STACK_DIR="$SCRIPT_DIR/providers/$TARGET"
[ -d "$STACK_DIR" ] || { echo "Répertoire de stack introuvable: $STACK_DIR" >&2; exit 1; }

if [ "$TARGET" = "runpod" ] && [ -z "${RUNPOD_API_KEY:-}" ]; then
  echo "ERREUR: RUNPOD_API_KEY n'est pas défini (export RUNPOD_API_KEY=...)." >&2
  exit 1
fi

if [ "$TARGET" = "exoscale" ] && { [ -z "${EXOSCALE_API_KEY:-}" ] || [ -z "${EXOSCALE_API_SECRET:-}" ]; }; then
  echo "ERREUR: EXOSCALE_API_KEY et EXOSCALE_API_SECRET doivent être définis." >&2
  exit 1
fi

if [ "$TARGET" = "vastai" ] && [ -z "${VASTAI_API_KEY:-}" ]; then
  echo "ERREUR: VASTAI_API_KEY n'est pas défini (export VASTAI_API_KEY=...)." >&2
  exit 1
fi

if [ "$TARGET" = "ovhcloud" ] && [ -z "${OS_AUTH_URL:-}" ]; then
  echo "ERREUR: identifiants OpenStack absents (source le fichier OpenStack RC : 'source openrc.sh')." >&2
  exit 1
fi

cd "$STACK_DIR"

# Initialise si nécessaire (télécharge les providers)
[ -d .terraform ] || terraform init -input=false

case "$ACTION" in
  up)
    terraform apply -auto-approve
    echo
    echo "== Sorties =="
    terraform output
    ;;
  down)
    terraform destroy -auto-approve
    ;;
  status)
    terraform output
    ;;
  *)
    echo "Action inconnue: '$ACTION'" >&2
    usage
    ;;
esac
