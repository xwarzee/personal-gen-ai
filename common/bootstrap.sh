#!/usr/bin/env bash
###############################################################################
# Bootstrap partagé Open WebUI + Ollama
#
# Logique métier commune aux deux cibles de déploiement (AWS EC2 / RunPod).
# Le script s'auto-adapte à son environnement :
#
#   - Mode HÔTE (Docker présent, ex. EC2 Deep Learning AMI) :
#       crée les volumes, lance le conteneur open-webui:ollama sur le port
#       3000, puis (optionnel) pré-télécharge un modèle Ollama.
#
#   - Mode CONTENEUR (pas de Docker mais `ollama` sur le PATH, ex. le pod
#       RunPod qui EST déjà l'image open-webui:ollama) :
#       le conteneur est déjà lancé par la plateforme, on se contente de
#       (optionnel) pré-télécharger le modèle.
#
# Variables d'environnement :
#   OLLAMA_MODEL   modèle à pré-télécharger (ex. "llama3.2"). Vide => aucun.
#   OPENWEBUI_IMAGE image à lancer en mode hôte (défaut open-webui:ollama).
#   HOST_PORT      port hôte exposé en mode hôte (défaut 3000).
###############################################################################
set -eu

OLLAMA_MODEL="${OLLAMA_MODEL:-}"
OPENWEBUI_IMAGE="${OPENWEBUI_IMAGE:-ghcr.io/open-webui/open-webui:ollama}"
HOST_PORT="${HOST_PORT:-3000}"

log() { echo "[bootstrap] $*"; }

pull_model() {
  # $1 = commande ollama (ex. "ollama" ou "docker exec open-webui ollama")
  [ -z "$OLLAMA_MODEL" ] && { log "Aucun OLLAMA_MODEL défini, pas de pré-téléchargement."; return 0; }
  log "Attente du démarrage d'Ollama..."
  for _ in $(seq 1 60); do
    if $1 list >/dev/null 2>&1; then break; fi
    sleep 5
  done
  log "Pré-téléchargement du modèle: $OLLAMA_MODEL"
  $1 pull "$OLLAMA_MODEL" || log "AVERTISSEMENT: échec du pull de $OLLAMA_MODEL (récupérable via l'UI)."
}

if command -v docker >/dev/null 2>&1; then
  #############################################################################
  # Mode HÔTE
  #############################################################################
  log "Docker détecté -> mode hôte."
  docker volume create ollama >/dev/null
  docker volume create open-webui >/dev/null

  if ! docker ps -a --format '{{.Names}}' | grep -qx open-webui; then
    log "Lancement du conteneur open-webui..."
    docker run -d -p "${HOST_PORT}:8080" --gpus=all \
      -v ollama:/root/.ollama \
      -v open-webui:/app/backend/data \
      --name open-webui \
      --restart always \
      "$OPENWEBUI_IMAGE"
  else
    log "Conteneur open-webui déjà présent."
  fi

  pull_model "docker exec open-webui ollama"

elif command -v ollama >/dev/null 2>&1; then
  #############################################################################
  # Mode CONTENEUR (RunPod : l'image est déjà le service)
  #############################################################################
  log "Ollama détecté sans Docker -> mode conteneur."
  pull_model "ollama"

else
  log "Ni Docker ni Ollama trouvés — rien à faire."
fi
