#!/usr/bin/env bats
# Tests de common/bootstrap.sh : détection de mode (hôte / conteneur / noop).

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  BOOT="$ROOT/common/bootstrap.sh"
  MOCKS="$BATS_TEST_DIRNAME/mocks/bin"
  BASH_BIN="$(command -v bash)"
  MOCK_LOG="$(mktemp)"; export MOCK_LOG

  # PATH « propre » : coreutils nécessaires à bootstrap, SANS docker ni ollama
  CLEANBIN="$(mktemp -d)"
  for u in grep seq sleep cat sed; do
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
  grep -q "docker: run" "$MOCK_LOG"
  ! grep -q "pull" "$MOCK_LOG"
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
