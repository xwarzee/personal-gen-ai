#!/usr/bin/env bats
# Tests de common/bootstrap.sh : détection de mode (hôte / conteneur / noop).

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  BOOT="$ROOT/common/bootstrap.sh"
  MOCKS="$BATS_TEST_DIRNAME/mocks/bin"
  BASH_BIN="$(command -v bash)"
  MOCK_LOG="$(mktemp)"; export MOCK_LOG

  # PATH « propre » : coreutils nécessaires à bootstrap, SANS docker ni ollama
  # (ni vllm ni curl : le health-check vLLM échoue donc et déclenche le start).
  CLEANBIN="$(mktemp -d)"
  for u in grep seq sleep cat sed mkdir nohup; do
    p="$(command -v "$u" 2>/dev/null)" && ln -sf "$p" "$CLEANBIN/$u"
  done
}

teardown() { rm -f "$MOCK_LOG"; rm -rf "$CLEANBIN" "$TOOLBIN"; }

# Crée un répertoire PATH exposant uniquement les mocks listés en arguments
make_toolbin() {
  TOOLBIN="$(mktemp -d)"
  for t in "$@"; do ln -sf "$MOCKS/$t" "$TOOLBIN/$t"; done
}

@test "mode hôte (docker présent, modèle vide) -> run sans pull" {
  make_toolbin docker ollama
  OLLAMA_MODEL="" PATH="$TOOLBIN:$CLEANBIN" run "$BASH_BIN" "$BOOT"
  [ "$status" -eq 0 ]
  grep -q "docker: volume create ollama" "$MOCK_LOG"
  grep -q "docker: volume create open-webui" "$MOCK_LOG"
  grep -q "docker: run" "$MOCK_LOG"
  grep -q -- "-v ollama:/root/.ollama" "$MOCK_LOG"
  grep -q -- "-v open-webui:/app/backend/data" "$MOCK_LOG"
  ! grep -q "pull" "$MOCK_LOG"
}

@test "mode hôte avec chemins persistants -> monte les chemins fournis" {
  make_toolbin docker ollama
  DATA_ROOT="$(mktemp -d)"
  OLLAMA_DATA_DIR="$DATA_ROOT/ollama" OPENWEBUI_DATA_DIR="$DATA_ROOT/open-webui" OLLAMA_MODEL="" PATH="$TOOLBIN:$CLEANBIN" run "$BASH_BIN" "$BOOT"
  [ "$status" -eq 0 ]
  grep -q -- "-v $DATA_ROOT/ollama:/root/.ollama" "$MOCK_LOG"
  grep -q -- "-v $DATA_ROOT/open-webui:/app/backend/data" "$MOCK_LOG"
  ! grep -q "docker: volume create ollama" "$MOCK_LOG"
  rm -rf "$DATA_ROOT"
}

@test "mode conteneur (ollama présent, docker absent) -> pull du modèle" {
  make_toolbin ollama
  OLLAMA_MODEL="llama3.2" PATH="$TOOLBIN:$CLEANBIN" run "$BASH_BIN" "$BOOT"
  [ "$status" -eq 0 ]
  grep -q "ollama: pull llama3.2" "$MOCK_LOG"
}

@test "aucun outil -> noop, exit 0" {
  PATH="$CLEANBIN" run "$BASH_BIN" "$BOOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rien à faire"* ]]
}

@test "vLLM mode hôte (ENGINE=vllm + docker) -> run vllm/vllm-openai sur 8000" {
  make_toolbin docker
  ENGINE="vllm" PATH="$TOOLBIN:$CLEANBIN" run "$BASH_BIN" "$BOOT"
  [ "$status" -eq 0 ]
  grep -q "docker: volume create vllm-cache" "$MOCK_LOG"
  grep -q "docker: run" "$MOCK_LOG"
  grep -q -- "-p 8000:8000" "$MOCK_LOG"
  grep -q -- "-v vllm-cache:/root/.cache/huggingface" "$MOCK_LOG"
  grep -q "vllm/vllm-openai:latest" "$MOCK_LOG"
  grep -q -- "--model Qwen/Qwen2.5-1.5B-Instruct" "$MOCK_LOG"
  # aucun résidu Open WebUI / Ollama
  ! grep -q "open-webui" "$MOCK_LOG"
  ! grep -q "volume create ollama" "$MOCK_LOG"
}

@test "vLLM mode conteneur (ENGINE=vllm + vllm, sans docker) -> démarre le serveur" {
  make_toolbin vllm
  VLLM_LOG="$(mktemp)"
  ENGINE="vllm" VLLM_LOG="$VLLM_LOG" PATH="$TOOLBIN:$CLEANBIN" run "$BASH_BIN" "$BOOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Démarrage du serveur vLLM"* ]]
  [[ "$output" == *"port 8000"* ]]
  # pas de bascule vers Ollama / Open WebUI
  ! grep -q "ollama:" "$MOCK_LOG"
  rm -f "$VLLM_LOG"
}

@test "moteur par défaut (ENGINE non défini) -> Open WebUI, pas de vLLM" {
  make_toolbin docker ollama
  OLLAMA_MODEL="" PATH="$TOOLBIN:$CLEANBIN" run "$BASH_BIN" "$BOOT"
  [ "$status" -eq 0 ]
  grep -q "open-webui" "$MOCK_LOG"
  ! grep -q "vllm" "$MOCK_LOG"
}
