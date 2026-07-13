#!/usr/bin/env bash
###############################################################################
# Dispatcher de déploiement multi-cible pour personal-gen-ai
#
# Usage:
#   ./deploy.sh <aws|runpod|exoscale|vastai|ovhcloud|lyceum> <up|down|purge|status>
#
#   up      provisionne la stack (terraform apply)
#   down    détruit le compute coûteux en conservant les données quand possible
#   purge   détruit toute la stack, données incluses
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
  echo "Usage: $0 <aws|runpod|exoscale|vastai|ovhcloud|lyceum> <up|down|purge|status>" >&2
  exit 2
}

[ $# -eq 2 ] || usage
TARGET="$1"
ACTION="$2"

case "$TARGET" in
  aws|runpod|exoscale|vastai|ovhcloud|lyceum) ;;
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

if [ "$TARGET" = "lyceum" ]; then
  if [ -z "${LYCEUM_API_KEY:-}" ]; then
    echo "ERREUR: LYCEUM_API_KEY n'est pas défini (export LYCEUM_API_KEY=lk_...)." >&2
    exit 1
  fi
  export TF_VAR_api_key="$LYCEUM_API_KEY"
fi

cd "$STACK_DIR"

# Initialise si nécessaire (télécharge les providers)
[ -d .terraform ] || terraform init -input=false

down_preserve_data() {
  case "$TARGET" in
    aws)
      terraform destroy -auto-approve \
        -target=aws_volume_attachment.ollama \
        -target=aws_volume_attachment.openwebui \
        -target=aws_instance.gpu_instance
      ;;
    exoscale)
      terraform destroy -auto-approve \
        -target=exoscale_compute_instance.gpu
      ;;
    ovhcloud)
      terraform destroy -auto-approve \
        -target=openstack_compute_volume_attach_v2.ollama \
        -target=openstack_compute_volume_attach_v2.openwebui \
        -target=openstack_compute_instance_v2.gpu
      ;;
    runpod)
      echo "AVERTISSEMENT: RunPod expose le volume persistant comme attribut du pod ; sa conservation dépend du provider RunPod."
      terraform destroy -auto-approve -target=runpod_pod.gpu
      ;;
    vastai)
      echo "AVERTISSEMENT: Vast.ai ne fournit pas de volume détachable dans cette stack ; down détruit l'instance et ses données."
      terraform destroy -auto-approve -target=vastai_instance.gpu
      ;;
    lyceum)
      echo "AVERTISSEMENT: Lyceum ne fournit pas de volume détachable dans cette stack ; down détruit la VM et ses données."
      terraform destroy -auto-approve -target=restapi_object.vm
      ;;
  esac
}

case "$ACTION" in
  up)
    terraform apply -auto-approve
    echo
    echo "== Sorties =="
    terraform output
    ;;
  down)
    down_preserve_data
    ;;
  purge)
    echo "AVERTISSEMENT: purge détruit toute la stack Terraform, y compris les volumes et données persistantes."
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
