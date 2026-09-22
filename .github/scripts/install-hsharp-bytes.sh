#!/usr/bin/env bash
# install-hsharp-bytes.sh
#
# Pobiera i instaluje najnowsze binarki kompilatora `hsharp` oraz menedżera
# pakietów `bytes`, wykrywając najnowszą wersję (tag release'u) każdego z
# repozytoriów przez GitHub API — bez zaszytych na sztywno numerów wersji.
#
#   hsharp -> https://github.com/HackerOS-Linux-System/H-Sharp/releases/download/<tag>/hsharp
#   bytes  -> https://github.com/Bytes-Repository/bytes/releases/download/<tag>/bytes
#
# Usage: install-hsharp-bytes.sh [install-dir]
#   install-dir defaults to "$HOME/.local/bin" (no sudo required).
#
# Outputs (when run as a step with `id:` set, appended to $GITHUB_OUTPUT):
#   hsharp-version, bytes-version

set -euo pipefail

HSHARP_REPO="HackerOS-Linux-System/H-Sharp"
BYTES_REPO="Bytes-Repository/bytes"
INSTALL_DIR="${1:-$HOME/.local/bin}"

mkdir -p "$INSTALL_DIR"

auth_header=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

# Zwraca tag najnowszego (nie-prerelease) release'u danego repo, np. "v1.4.2".
fetch_latest_tag() {
  local repo="$1"
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "${auth_header[@]}" \
    "https://api.github.com/repos/${repo}/releases/latest" \
  | jq -r '.tag_name // empty'
}

# Pobiera i instaluje jedną binarkę z release'u danego repo.
install_binary() {
  local repo="$1" bin_name="$2" tag url

  tag="$(fetch_latest_tag "$repo")"
  if [ -z "$tag" ]; then
    echo "::error::Nie udało się wykryć najnowszej wersji dla ${repo} (GitHub API zwróciło pusty tag_name)" >&2
    exit 1
  fi

  url="https://github.com/${repo}/releases/download/${tag}/${bin_name}"
  echo "→ ${bin_name}: najnowsza wersja = ${tag}"
  echo "→ pobieranie: ${url}"

  if ! curl -fL --retry 3 --retry-delay 2 -o "${INSTALL_DIR}/${bin_name}" "$url"; then
    echo "::error::Nie udało się pobrać ${bin_name} z ${url}" >&2
    exit 1
  fi

  chmod +x "${INSTALL_DIR}/${bin_name}"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "${bin_name}-version=${tag}" >> "$GITHUB_OUTPUT"
  fi
}

install_binary "$HSHARP_REPO" "hsharp"
install_binary "$BYTES_REPO" "bytes"

echo ""
echo "Zainstalowano do: ${INSTALL_DIR}"
echo "PATH musi zawierać ten katalog — w workflow dodaj go przez:"
echo '  echo "'"$INSTALL_DIR"'" >> "$GITHUB_PATH"'
echo ""
echo "-- wersje --"
"${INSTALL_DIR}/hsharp" --version || echo "(uwaga: 'hsharp --version' zwróciło błąd)"
"${INSTALL_DIR}/bytes" --version  || echo "(uwaga: 'bytes --version' zwróciło błąd)"
