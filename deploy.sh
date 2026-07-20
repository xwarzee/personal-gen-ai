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

# Pré-check du solde Vast.ai. Le provider traduit TOUT HTTP 400/404 de la
# création par un trompeur "Offer No Longer Available" ; en particulier, un
# compte sans crédit (Vast.ai est prépayé) échoue ainsi sur chaque offre.
# On coupe tôt avec un message actionnable. Best-effort : en cas de doute
# (API injoignable, JSON illisible), on n'empêche pas le déploiement.
vastai_check_credit() {
  local resp credit can_pay
  resp="$(curl -fsS "https://console.vast.ai/api/v0/users/current/?api_key=${VASTAI_API_KEY}" 2>/dev/null)" || {
    echo "AVERTISSEMENT: solde Vast.ai non vérifiable (pré-check ignoré)." >&2
    return 0
  }

  if command -v python3 >/dev/null 2>&1; then
    credit="$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("credit",""))' 2>/dev/null)"
    can_pay="$(printf '%s' "$resp" | python3 -c 'import sys,json;print(str(json.load(sys.stdin).get("can_pay","")).lower())' 2>/dev/null)"
  else
    credit="$(printf '%s' "$resp" | grep -oE '"credit"[[:space:]]*:[[:space:]]*-?[0-9.]+' | grep -oE '\-?[0-9.]+$')"
    can_pay="$(printf '%s' "$resp" | grep -oE '"can_pay"[[:space:]]*:[[:space:]]*(true|false)' | grep -oE '(true|false)$')"
  fi

  # Blocage uniquement si le compte n'a ni crédit ni moyen de paiement :
  # (credit <= 0) ET (can_pay == false). Ainsi on ne bloque pas à tort un
  # compte qui peut être facturé automatiquement ou qui a du crédit restant.
  if [ "$can_pay" = "false" ] && [ -n "$credit" ] && awk "BEGIN{exit !(${credit} <= 0)}" 2>/dev/null; then
    echo "ERREUR: compte Vast.ai sans crédit (credit=${credit}) ni moyen de paiement (can_pay=false)." >&2
    echo "        Vast.ai est prépayé : créditez le compte avant de déployer." >&2
    echo "        Page billing : https://cloud.vast.ai/billing/" >&2
    echo "        (Sans crédit, le provider affiche à tort « Offer No Longer Available ».)" >&2
    return 1
  fi

  return 0
}

# Les offres Vast.ai sont éphémères : l'offre retenue au plan peut être
# réservée par un autre utilisateur avant la création de l'instance
# ("Offer No Longer Available"). On relance alors l'apply, qui re-cherche
# une offre fraîche. On ne réessaie QUE sur cette erreur de disponibilité.
vastai_up_with_retry() {
  local max_attempts=5 attempt=1 rc delay log
  log="$(mktemp)"
  while :; do
    echo "== Tentative ${attempt}/${max_attempts} : terraform apply =="
    rc=0
    terraform apply -auto-approve 2>&1 | tee "$log" || rc=${PIPESTATUS[0]}

    if [ "$rc" -eq 0 ]; then
      rm -f "$log"
      return 0
    fi

    if ! grep -qiE "Offer No Longer Available|is no longer available" "$log"; then
      echo "ERREUR non liée à la disponibilité des offres ; arrêt." >&2
      rm -f "$log"
      return "$rc"
    fi

    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "ERREUR: offre toujours indisponible après ${max_attempts} tentatives." >&2
      rm -f "$log"
      return "$rc"
    fi

    delay=$((attempt * 3))
    echo "Offre réservée entre-temps ; nouvelle recherche dans ${delay}s…" >&2
    sleep "$delay"
    attempt=$((attempt + 1))
  done
}

case "$ACTION" in
  up)
    if [ "$TARGET" = "vastai" ]; then
      vastai_check_credit
      vastai_up_with_retry
    else
      terraform apply -auto-approve
    fi
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
