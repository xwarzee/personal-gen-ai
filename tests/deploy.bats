#!/usr/bin/env bats
# Tests du dispatcher deploy.sh : garde-fous et routage.

setup() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"   # terraform mocké en tête de PATH
  MOCK_LOG="$(mktemp)"; export MOCK_LOG
  # Neutralise les clés d'API pour exercer les garde-fous
  unset RUNPOD_API_KEY EXOSCALE_API_KEY EXOSCALE_API_SECRET VASTAI_API_KEY OS_AUTH_URL LYCEUM_API_KEY
}

teardown() { rm -f "$MOCK_LOG"; }

@test "cible inconnue -> exit 2 + usage" {
  run "$PROJECT_ROOT/deploy.sh" foo up
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"purge"* ]]
}

@test "action manquante -> exit 2" {
  run "$PROJECT_ROOT/deploy.sh" aws
  [ "$status" -eq 2 ]
}

@test "runpod sans RUNPOD_API_KEY -> exit 1" {
  run "$PROJECT_ROOT/deploy.sh" runpod up
  [ "$status" -eq 1 ]
  [[ "$output" == *"RUNPOD_API_KEY"* ]]
}

@test "exoscale sans clés -> exit 1" {
  run "$PROJECT_ROOT/deploy.sh" exoscale up
  [ "$status" -eq 1 ]
  [[ "$output" == *"EXOSCALE_API_KEY"* ]]
}

@test "vastai sans VASTAI_API_KEY -> exit 1" {
  run "$PROJECT_ROOT/deploy.sh" vastai up
  [ "$status" -eq 1 ]
  [[ "$output" == *"VASTAI_API_KEY"* ]]
}

@test "ovhcloud sans identifiants OpenStack -> exit 1" {
  run "$PROJECT_ROOT/deploy.sh" ovhcloud up
  [ "$status" -eq 1 ]
  [[ "$output" == *"OpenStack RC"* ]]
}

@test "lyceum sans LYCEUM_API_KEY -> exit 1" {
  run "$PROJECT_ROOT/deploy.sh" lyceum up
  [ "$status" -eq 1 ]
  [[ "$output" == *"LYCEUM_API_KEY"* ]]
}

@test "aws status -> routage vers 'terraform output' dans aws/" {
  run "$PROJECT_ROOT/deploy.sh" aws status
  [ "$status" -eq 0 ]
  grep -q "terraform: output (cwd=aws)" "$MOCK_LOG"
}

@test "aws down -> détruit le compute et conserve les volumes de données" {
  run "$PROJECT_ROOT/deploy.sh" aws down
  [ "$status" -eq 0 ]
  grep -q "terraform: destroy -auto-approve -target=aws_volume_attachment.ollama -target=aws_volume_attachment.openwebui -target=aws_instance.gpu_instance (cwd=aws)" "$MOCK_LOG"
}

@test "aws purge -> destroy complet" {
  run "$PROJECT_ROOT/deploy.sh" aws purge
  [ "$status" -eq 0 ]
  [[ "$output" == *"purge détruit toute la stack"* ]]
  grep -q "terraform: destroy -auto-approve (cwd=aws)" "$MOCK_LOG"
}
