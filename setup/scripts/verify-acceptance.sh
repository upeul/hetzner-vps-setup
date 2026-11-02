#!/usr/bin/env bash
# Aceite local de controles. Evidência externa ausente impede aceite de produção.
# Uso com TTY: ssh -t admin@100.x.x.x 'bash /tmp/verify-acceptance.sh'
# --container-smoke limita o escopo e não certifica a VPS de produção.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
pass=0
fail=0
inconclusive=0
skipped=0
container_smoke=false
case "${1:-}" in
  "") ;;
  --container-smoke) container_smoke=true ;;
  *) echo "Uso: $0 [--container-smoke]" >&2; exit 2 ;;
esac
export LC_ALL=C
ADMIN_USER="${ADMIN_USER:-admin}"
DEV_ROOT="${DEV_ROOT:-/srv/dev}"
users=(ide agent-claude agent-codex agent-grok)
expected_users=("$ADMIN_USER" "${users[@]}")

ok() { echo -e "${GREEN}PASS${NC} $1"; pass=$((pass+1)); }
bad() { echo -e "${RED}FAIL${NC} $1"; fail=$((fail+1)); }
warn() { echo -e "${YELLOW}WARN${NC} $1"; }
unknown() { echo -e "${YELLOW}INCONCLUSIVE${NC} $1"; inconclusive=$((inconclusive+1)); }
external() {
  if "$container_smoke"; then
    echo "SKIP (container-smoke) $1"
    skipped=$((skipped+1))
  else
    unknown "$1"
  fi
}

echo "=== VPS dev acceptance checks ==="

if [[ ! -t 0 ]] && [[ ! -t 1 ]]; then
  echo "Precisa de TTY para sudo. Use: ssh -t ... 'bash $0'"
  exit 2
fi

# Cache sudo (pede senha do admin uma vez)
if ! sudo -n true 2>/dev/null; then
  echo "Autenticando sudo (senha do admin)..."
  sudo -v
fi

# Toda concessão sudo, mesmo limitada a um comando, viola o contrato.
for u in "${users[@]}"; do
  if ! id "$u" &>/dev/null; then
    bad "usuário $u não existe"
    continue
  fi
  out="$(sudo -l -U "$u" 2>&1 || true)"
  if grep -q "is not allowed to run sudo" <<<"$out"; then
    ok "$u sem concessões sudo"
  elif grep -qE '^[[:space:]]+\([^)]*\)[[:space:]]+!ALL[[:space:]]*$' <<<"$out" &&
       ! grep -E '^[[:space:]]+\(' <<<"$out" | grep -qvE '^[[:space:]]+\([^)]*\)[[:space:]]+!ALL[[:space:]]*$' &&
       ! sudo -l -U "$u" /usr/bin/true >/dev/null 2>&1; then
    ok "$u com negação sudo explícita !ALL e comando negado"
  elif grep -qE 'may run the following commands|NOPASSWD:|PASSWD:|^[[:space:]]+\(' <<<"$out"; then
    bad "$u tem concessões sudo: $out"
  else
    unknown "$u: não foi possível determinar concessões sudo: $out"
  fi
done

# Valores efetivos, inclusive Match por usuário no contexto da conexão SSH.
# O modo container cobre apenas configuração global, não autenticação remota.
ssh_context=()
if [[ -n "${SSH_CONNECTION:-}" ]]; then
  read -r remote_addr _remote_port local_addr local_port <<<"$SSH_CONNECTION"
  ssh_context=(-C "addr=$remote_addr,host=$remote_addr,laddr=$local_addr,lport=$local_port")
elif ! "$container_smoke"; then
  unknown "sem SSH_CONNECTION: contexto remoto de sshd Match não demonstrado"
fi
for u in "${expected_users[@]}"; do
  context=("${ssh_context[@]}")
  if ((${#context[@]})); then context[1]="${context[1]},user=$u"; fi
  if ! sshd_dump="$(sudo /usr/sbin/sshd -T "${context[@]}" 2>&1)"; then
    unknown "sshd -T para $u falhou: $sshd_dump"
    continue
  fi
  for setting in permitrootlogin passwordauthentication kbdinteractiveauthentication x11forwarding; do
    if grep -qx "$setting no" <<<"$sshd_dump"; then
      ok "sshd efetivo $u: $setting no"
    else
      bad "sshd efetivo $u: esperado $setting no"
    fi
  done
  allowed="$(awk '$1 == "allowusers" {for (i=2;i<=NF;i++) print $i}' <<<"$sshd_dump" | sort -u)"
  expected="$(printf '%s\n' "${expected_users[@]}" | sort -u)"
  if [[ "$allowed" == "$expected" ]]; then
    ok "sshd efetivo $u: AllowUsers exato"
  else
    bad "sshd efetivo $u: AllowUsers diferente: $allowed"
  fi
done

# Tailscale e destino overlay são obrigatórios na produção.
if "$container_smoke"; then
  external "tailnet ativa, endereço local e Tailscale SSH desabilitado não exercidos"
elif ! command -v tailscale >/dev/null; then
  unknown "Tailscale indisponível; destino tailnet não comprovado"
else
  if tailscale status --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
sys.exit(0 if d.get("BackendState") == "Running" and d.get("Self", {}).get("TailscaleIPs") else 1)
'; then
    ok "tailnet ativa com endereço local"
  else
    unknown "tailnet offline ou endereço local indisponível"
  fi
  if sudo tailscale debug prefs | python3 -c '
import json, sys
d = json.load(sys.stdin)
sys.exit(0 if d.get("RunSSH") is False else 1)
'; then
    ok "Tailscale SSH desabilitado; OpenSSH atende a tailnet"
  else
    unknown "Tailscale SSH não comprovadamente desabilitado"
  fi
fi

# UFW: defaults efetivos e únicas permissões de entrada na interface overlay.
if ufw_out="$(sudo ufw status verbose 2>&1)"; then
  if grep -qx 'Status: active' <<<"$ufw_out"; then ok "UFW ativo"; else bad "UFW inativo"; fi
  if grep -qE '^Default: deny \(incoming\),' <<<"$ufw_out"; then
    ok "UFW default deny incoming"
  else
    bad "UFW sem default deny incoming"
  fi
  if grep -qE '(22/tcp|OpenSSH).*on tailscale0[[:space:]]+ALLOW IN' <<<"$ufw_out"; then
    ok "UFW permite OpenSSH na tailscale0"
  else
    unknown "regra UFW para OpenSSH na tailscale0 não encontrada"
  fi
  if grep -qE '(22/tcp|OpenSSH).*\(v6\).*on tailscale0[[:space:]]+ALLOW IN' <<<"$ufw_out"; then
    ok "UFW regra OpenSSH overlay IPv6 carregada"
  else
    unknown "regra UFW overlay IPv6 não encontrada"
  fi
  if grep 'ALLOW IN' <<<"$ufw_out" | grep -qv 'on tailscale0'; then
    bad "UFW contém permissão de entrada fora da tailscale0: $ufw_out"
  fi
else
  unknown "UFW ilegível: $ufw_out"
fi

# Diretórios privados: dono acessa, todos os outros UIDs geridos são negados.
private_paths=("${DEV_ROOT}/worktrees/ide" "${DEV_ROOT}/worktrees/claude" "${DEV_ROOT}/worktrees/codex" "${DEV_ROOT}/worktrees/grok")
for i in "${!users[@]}"; do
  owner="${users[$i]}"
  home="$(getent passwd "$owner" | cut -d: -f6 || true)"
  paths=("$home")
  if [[ -n "${private_paths[$i]:-}" ]]; then paths+=("${private_paths[$i]}"); fi
  for path in "${paths[@]}"; do
    if [[ -z "$path" || ! -d "$path" ]]; then
      bad "diretório privado ausente para $owner: $path"
      continue
    fi
    if [[ "$(stat -c %U "$path")" == "$owner" ]] && sudo -u "$owner" test -x "$path"; then
      ok "$owner acessa seu diretório $path"
    else
      bad "dono/acesso incorreto em $path"
    fi
    for other in "${users[@]}"; do
      [[ "$other" == "$owner" ]] && continue
      if sudo -u "$other" test -r "$path" || sudo -u "$other" test -w "$path" || sudo -u "$other" test -x "$path"; then
        bad "$other atravessa limite de UID em $path"
      elif id "$other" &>/dev/null; then
        ok "$other sem acesso a $path"
      else
        unknown "UID de teste $other ausente"
      fi
    done
  done
done

# A allowlist legível é política administrativa, não isolamento de repositórios.
for u in "${users[@]}"; do
  if sudo -u "$u" test -r "${DEV_ROOT}/repo-allowlist.yaml"; then
    ok "$u lê política administrativa de repositórios (não bloqueia clone)"
  else
    bad "$u não consegue ler política de repositórios"
  fi
done

# Provar regras carregadas e modo, não a existência do arquivo renderizado.
egress_mode="${EGRESS_MODE:-observe}"
case "$egress_mode" in
  observe|enforce) ;;
  *) echo "EGRESS_MODE deve ser observe ou enforce" >&2; exit 2 ;;
esac
if sudo nft -n -j list table inet egress_allow | python3 -c '
import json, pwd, sys
mode = sys.argv[1]
objects = json.load(sys.stdin)["nftables"]
chains = [o["chain"] for o in objects if "chain" in o]
rules = [o["rule"] for o in objects if "rule" in o]
sets = [o["set"] for o in objects if "set" in o]
output = [c for c in chains if c["name"] == "output"]
assert len(output) == 1 and all(output[0].get(k) == v for k, v in
    {"type": "filter", "hook": "output", "prio": 100, "policy": "accept"}.items()), "output hook"
route = [r for r in rules if r["chain"] == "output" and r.get("comment") == f"egress mode: {mode}"]
assert len(route) == 1, "mode marker"
expr = route[0]["expr"]
assert any(e.get("jump", {}).get("target") == "agents" for e in expr), "agents jump"
assert any(e.get("match", {}).get("left") == {"meta": {"key": "skuid"}} and
    e["match"].get("right") == "@restricted_uids" and e["match"].get("op") == "==" for e in expr), "UID match"
uids = [s for s in sets if s["name"] == "restricted_uids"]
assert len(uids) == 1 and set(uids[0].get("elem", [])) == {
    pwd.getpwnam(u).pw_uid for u in sys.argv[2:]}, "restricted UIDs"
agents = [r for r in rules if r["chain"] == "agents"]
assert agents and agents[-1].get("comment") == f"egress unmatched: {mode}", "final mode rule"
verdict = "accept" if mode == "observe" else "drop"
assert any(verdict in e for e in agents[-1]["expr"]), "final verdict"
' "$egress_mode" "${users[@]}"; then
  ok "egress carregado: $egress_mode"
  if [[ "$egress_mode" == observe ]]; then
    warn "egress somente observação; nenhuma restrição de saída"
  else
    external "modo enforce: testes negativos de saída e recuperação externos não exercidos"
  fi
else
  unknown "tabela egress ausente, ilegível ou diferente do modo $egress_mode"
fi
if service_state="$(systemctl show devvps-egress.service -p Result -p ExecMainStatus -p ExecMainStartTimestampMonotonic)" &&
   grep -qx 'Result=success' <<<"$service_state" &&
   grep -qx 'ExecMainStatus=0' <<<"$service_state" &&
   grep -qE '^ExecMainStartTimestampMonotonic=[1-9][0-9]*$' <<<"$service_state"; then
  ok "devvps-egress.service executado com sucesso (oneshot pode estar inativo)"
else
  unknown "execução bem-sucedida de devvps-egress.service não comprovada"
fi
if systemctl is-active --quiet devvps-egress-refresh.timer &&
   systemctl is-enabled --quiet devvps-egress-refresh.timer; then
  ok "devvps-egress-refresh.timer ativo e habilitado"
else
  bad "devvps-egress-refresh.timer não está ativo e habilitado"
fi

# Não há cliente/API cloud nem login remoto novo neste script local.
external "firewall cloud anexado, IPv4/IPv6 e fechamento do SSH bootstrap sem evidência API externa"
external "login OpenSSH novo com chave para cada usuário e negação pela interface pública não exercidos"

# CVE-2026-98432 - mitigação até o kernel corrigido (role cve_2026_98432)
if [[ -e /proc/sys/net/mptcp/enabled ]]; then
  if mptcp="$(cat /proc/sys/net/mptcp/enabled 2>&1)"; then
    if [[ "$mptcp" == "0" ]]; then
      ok "MPTCP desligado (net.mptcp.enabled = 0)"
    else
      bad "MPTCP ligado (net.mptcp.enabled = $mptcp)"
    fi
  else
    bad "leitura de net.mptcp.enabled falhou: $mptcp"
  fi
elif [[ -d /proc/sys/net/ipv4 ]]; then
  ok "kernel sem MPTCP (/proc/sys/net/mptcp/enabled ausente)"
else
  bad "/proc/sys/net ilegível: estado do MPTCP inconclusivo"
fi

if mptcp_listeners="$(sudo ss -Hlnp --mptcp 2>&1)"; then
  if [[ -z "$mptcp_listeners" ]]; then
    ok "nenhum listener MPTCP"
  else
    bad "listeners MPTCP abertos (reinicie os serviços donos): $mptcp_listeners"
  fi
else
  bad "ss --mptcp falhou: $mptcp_listeners"
fi

# Chain inteira igual à do role (vars/main.yml): hook prerouting + regra de drop
cve_expected='table ip cve_2026_98432 { chain prerouting { type filter hook prerouting priority raw; policy accept; meta l4proto tcp ip hdrlength > 5 counter packets N bytes N drop } }'
cve_chain="$(sudo nft list chain ip cve_2026_98432 prerouting 2>&1 || true)"
cve_norm="$(tr -s '[:space:]' ' ' <<<"$cve_chain" | sed -E 's/packets [0-9]+ bytes [0-9]+/packets N bytes N/; s/^ //; s/ $//')"
if [[ "$cve_norm" == "$cve_expected" ]]; then
  ok "regra CVE-2026-98432 carregada (TCP/IPv4 com opções IP descartado)"
else
  bad "regra CVE-2026-98432 ausente ou diferente (chain ip cve_2026_98432 prerouting): $cve_chain"
fi

if systemctl is-enabled --quiet cve-2026-98432 2>/dev/null; then
  ok "cve-2026-98432.service habilitado (regra volta no boot)"
else
  bad "cve-2026-98432.service não habilitado (regra some no reboot)"
fi

if [[ -f /var/run/reboot-required ]]; then
  warn "reboot pendente: kernel novo instalado só vale depois do reboot"
fi
echo "INFO kernel em execução $(uname -r): a mitigação não corrige o bug; compare com https://ubuntu.com/security/CVE-2026-98432"

echo ""
echo "Resultado: $pass PASS, $fail FAIL, $inconclusive INCONCLUSIVE, $skipped SKIP"
if "$container_smoke"; then
  echo "Escopo: smoke local em contêiner; não é aceite de produção."
fi
[[ "$fail" -eq 0 && "$inconclusive" -eq 0 ]]
