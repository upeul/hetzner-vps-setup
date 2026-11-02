#!/usr/bin/env bash
# Imprime instruções manuais. Não instala binários nem credenciais.
set -euo pipefail

cat <<'GUIDE'
=== Instruções de CLIs por usuário (nenhuma instalação executada) ===
Pré-requisito: aceite de produção e revisão de acesso/credenciais concluídos.
O egress padrão (observe) é somente observação: não restringe saída à internet.
A role base instala nodejs e npm para Codex; confirmar a versão suportada
na documentação oficial do Codex antes de instalar.

Claude Code (sessão separada como agent-claude):
  sudo -iu agent-claude
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  claude
  # Na interface interativa do Claude, executar /login.
  exit
Documentação: https://code.claude.com/docs/en/setup

Codex (sessão separada como agent-codex, sem sudo para npm):
  sudo -iu agent-codex
  mkdir -p "$HOME/.local"
  npm config set prefix "$HOME/.local"
  export PATH="$HOME/.local/bin:$PATH"
  npm install -g @openai/codex
  codex login
  exit
Persistir PATH="$HOME/.local/bin:$PATH" no perfil do próprio usuário.
Documentação: https://developers.openai.com/codex/cli/

Grok: integração opcional não implementada. Este pacote não fornece nem
instala um CLI xAI suportado. A conta agent-grok não comprova essa capacidade.

Cursor Remote SSH:
  No Mac: conectar como ide pelo endereço Tailscale, nunca como admin.
  O servidor usa OpenSSH, não Tailscale SSH.

Repositórios:
  Ler /srv/dev/repo-allowlist.yaml antes de clonar no worktree do UID.
  A lista é política administrativa, não bloqueio técnico de clone.
  Usar credenciais de escopo mínimo separadas por UID. Não inserir segredos
  em comandos, histórico, repositórios ou perfis de shell.
GUIDE
