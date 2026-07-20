#!/usr/bin/env bash
###############################################################################
# Bootstrap partagé Open WebUI + Ollama
#
# Logique métier commune aux deux cibles de déploiement (AWS EC2 / RunPod).
# Le script s'auto-adapte à son environnement :
#
#   - Mode HÔTE (Docker présent, ex. EC2 Deep Learning AMI) :
#       prépare les sources de données persistantes, lance le conteneur
#       open-webui:ollama sur le port 3000, puis (optionnel) pré-télécharge
#       un modèle Ollama.
#
#   - Mode CONTENEUR (pas de Docker mais `ollama` sur le PATH, ex. le pod
#       RunPod, ou une instance Vast.ai en runtype ssh, qui EST déjà l'image
#       open-webui:ollama) :
#       démarre au besoin `ollama serve` et le backend Open WebUI (l'entrypoint
#       de l'image n'est pas toujours exécuté par la plateforme — cas de
#       Vast.ai en runtype ssh), puis (optionnel) pré-télécharge le modèle.
#       Idempotent : si la plateforme a déjà lancé les services (RunPod), on
#       ne relance rien.
#
# Le moteur de service se choisit via ENGINE :
#   ENGINE=openwebui (défaut) : Open WebUI + Ollama (UI navigateur, port 8080).
#   ENGINE=vllm               : serveur vLLM, API OpenAI-compatible (port 8000).
# La détection hôte/conteneur ci-dessus s'applique aux DEUX moteurs.
#
# Variables d'environnement :
#   ENGINE             "openwebui" (défaut) ou "vllm".
#   OLLAMA_MODEL       modèle à pré-télécharger (ex. "llama3.2"). Vide => aucun.
#   OLLAMA_DATA_DIR    chemin ou volume Docker pour Ollama (défaut: ollama).
#   OPENWEBUI_DATA_DIR chemin ou volume Docker pour Open WebUI (défaut: open-webui).
#   OPENWEBUI_IMAGE    image à lancer en mode hôte (défaut open-webui:ollama).
#   HOST_PORT          port hôte exposé en mode hôte (défaut 3000).
#   -- spécifiques vLLM (ENGINE=vllm) --
#   VLLM_MODEL         modèle HuggingFace servi (défaut Qwen/Qwen2.5-1.5B-Instruct).
#   VLLM_IMAGE         image conteneur vLLM en mode hôte (défaut vllm/vllm-openai:latest).
#   VLLM_PORT          port de l'API OpenAI-compatible (défaut 8000).
#   VLLM_EXTRA_ARGS    args CLI additionnels vLLM (ex. "--max-model-len 8192").
#   VLLM_CACHE_DIR     chemin/volume du cache HuggingFace en mode hôte (défaut vllm-cache).
#   VLLM_LOG           fichier de log du serveur vLLM (défaut /var/log/vllm.log).
#   HF_TOKEN           token HuggingFace pour modèles gated (vide => aucun).
###############################################################################
set -eu

ENGINE="${ENGINE:-openwebui}"

OLLAMA_MODEL="${OLLAMA_MODEL:-}"
OLLAMA_DATA_DIR="${OLLAMA_DATA_DIR:-ollama}"
OPENWEBUI_DATA_DIR="${OPENWEBUI_DATA_DIR:-open-webui}"
OPENWEBUI_IMAGE="${OPENWEBUI_IMAGE:-ghcr.io/open-webui/open-webui:ollama}"
HOST_PORT="${HOST_PORT:-3000}"

VLLM_MODEL="${VLLM_MODEL:-Qwen/Qwen2.5-1.5B-Instruct}"
VLLM_IMAGE="${VLLM_IMAGE:-vllm/vllm-openai:latest}"
VLLM_PORT="${VLLM_PORT:-8000}"
VLLM_EXTRA_ARGS="${VLLM_EXTRA_ARGS:-}"
VLLM_CACHE_DIR="${VLLM_CACHE_DIR:-vllm-cache}"
VLLM_LOG="${VLLM_LOG:-/var/log/vllm.log}"
HF_TOKEN="${HF_TOKEN:-}"

log() { echo "[bootstrap] $*"; }

prepare_mount_source() {
  # $1 = chemin hôte ou nom de volume Docker.
  case "$1" in
    /* | ./* | ../*)
      mkdir -p "$1"
      ;;
    *)
      docker volume create "$1" >/dev/null
      ;;
  esac
}

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

start_vllm() {
  ###########################################################################
  # Moteur vLLM : serveur d'inférence exposant une API OpenAI-compatible.
  # Même détection hôte/conteneur que pour Open WebUI. Pas d'Ollama ici :
  # vLLM télécharge le modèle HuggingFace au démarrage.
  ###########################################################################
  if command -v docker >/dev/null 2>&1; then
    log "Docker détecté -> mode hôte (vLLM)."
    prepare_mount_source "$VLLM_CACHE_DIR"

    if ! docker ps -a --format '{{.Names}}' | grep -qx vllm; then
      log "Lancement du conteneur vLLM (API OpenAI-compatible)..."
      hf_env=""
      [ -n "$HF_TOKEN" ] && hf_env="-e HUGGING_FACE_HUB_TOKEN=$HF_TOKEN"
      # shellcheck disable=SC2086  # $hf_env / $VLLM_EXTRA_ARGS : découpage voulu
      docker run -d -p "${VLLM_PORT}:8000" --gpus=all \
        -v "${VLLM_CACHE_DIR}:/root/.cache/huggingface" \
        $hf_env \
        --name vllm \
        --restart always \
        "$VLLM_IMAGE" \
        --model "$VLLM_MODEL" $VLLM_EXTRA_ARGS
    else
      log "Conteneur vLLM déjà présent."
    fi

  elif command -v vllm >/dev/null 2>&1; then
    # L'image EST vllm/vllm-openai (Vast.ai runtype ssh). L'entrypoint n'étant
    # pas toujours exécuté par la plateforme, on démarre le serveur au besoin.
    log "vLLM détecté sans Docker -> mode conteneur."
    if ! curl -sf -o /dev/null "http://localhost:${VLLM_PORT}/health" 2>/dev/null; then
      log "Démarrage du serveur vLLM (OpenAI-compatible) sur le port ${VLLM_PORT}..."
      [ -n "$HF_TOKEN" ] && export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
      # shellcheck disable=SC2086  # $VLLM_EXTRA_ARGS : découpage voulu
      nohup vllm serve "$VLLM_MODEL" --host 0.0.0.0 --port "$VLLM_PORT" $VLLM_EXTRA_ARGS \
        >"$VLLM_LOG" 2>&1 &
    else
      log "Serveur vLLM déjà en écoute sur ${VLLM_PORT}."
    fi

  else
    log "Ni Docker ni vLLM trouvés — rien à faire."
  fi
}

if [ "$ENGINE" = "vllm" ]; then
  start_vllm
elif command -v docker >/dev/null 2>&1; then
  #############################################################################
  # Mode HÔTE
  #############################################################################
  log "Docker détecté -> mode hôte."
  prepare_mount_source "$OLLAMA_DATA_DIR"
  prepare_mount_source "$OPENWEBUI_DATA_DIR"

  if ! docker ps -a --format '{{.Names}}' | grep -qx open-webui; then
    log "Lancement du conteneur open-webui..."
    docker run -d -p "${HOST_PORT}:8080" --gpus=all \
      -v "${OLLAMA_DATA_DIR}:/root/.ollama" \
      -v "${OPENWEBUI_DATA_DIR}:/app/backend/data" \
      --name open-webui \
      --restart always \
      "$OPENWEBUI_IMAGE"
  else
    log "Conteneur open-webui déjà présent."
  fi

  pull_model "docker exec open-webui ollama"

elif command -v ollama >/dev/null 2>&1; then
  #############################################################################
  # Mode CONTENEUR (RunPod, Vast.ai runtype ssh : l'image EST le service)
  #############################################################################
  log "Ollama détecté sans Docker -> mode conteneur."

  # Certaines plateformes n'exécutent pas l'entrypoint de l'image (Vast.ai en
  # runtype ssh) : ni « ollama serve » ni le backend Open WebUI ne tournent.
  # On les démarre au besoin. Checks idempotents : si déjà lancés (RunPod),
  # on ne relance rien.

  # 1) ollama serve
  if ! ollama list >/dev/null 2>&1; then
    log "Démarrage d'ollama serve..."
    nohup ollama serve >/var/log/ollama.log 2>&1 &
    for _ in $(seq 1 30); do
      if ollama list >/dev/null 2>&1; then break; fi
      sleep 2
    done
  fi

  # 2) Backend Open WebUI (port 8080). On lance le start.sh de l'image, en
  #    forçant USE_OLLAMA_DOCKER=false puisqu'ollama est déjà démarré ci-dessus.
  #    OLLAMA_BASE_URL : l'image/Vast.ai la fixe à "/ollama" (reverse-proxy),
  #    invalide hors de ce proxy (on accède par tunnel SSH) -> on force l'URL
  #    absolue du serveur Ollama local, sinon Open WebUI ne voit aucun modèle.
  if ! curl -sf -o /dev/null "http://localhost:8080/health" 2>/dev/null; then
    if [ -f /app/backend/start.sh ]; then
      log "Démarrage du backend Open WebUI (start.sh)..."
      ( cd /app/backend \
        && OLLAMA_BASE_URL="http://localhost:11434" USE_OLLAMA_DOCKER=false \
           nohup bash start.sh >/var/log/open-webui.log 2>&1 & )
    else
      log "AVERTISSEMENT: /app/backend/start.sh introuvable ; Open WebUI non démarré."
    fi
  fi

  pull_model "ollama"

else
  log "Ni Docker ni Ollama trouvés — rien à faire."
fi
