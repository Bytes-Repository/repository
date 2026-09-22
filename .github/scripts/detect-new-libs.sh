#!/usr/bin/env bash
# detect-new-libs.sh
#
# Porównuje index.json z bieżącego commita względem index.json z commita
# bazowego i wypisuje listę bibliotek, które zostały DODANE (nowe wpisy
# {"nazwa": "url"}). Używane przez tests.yml i build-packages.yml, żeby
# CI testowało/budowało tylko nowo dodaną bibliotekę, a nie cały rejestr
# przy każdym pushu.
#
# Usage: detect-new-libs.sh <base-rev> [lib-name-filter]
#   <base-rev>        commit/ref, względem którego liczymy różnicę
#                      (np. github.event.pull_request.base.sha albo
#                      github.event.before). Może być pusty.
#   [lib-name-filter]  opcjonalnie: pomija diff i zwraca tylko wpis
#                      o podanej nazwie z bieżącego index.json — używane
#                      przy ręcznym workflow_dispatch na konkretną bibliotekę.
#
# W trybie GitHub Actions (gdy ustawione $GITHUB_OUTPUT) ustawia:
#   libs=<JSON array [{"name":...,"url":...}, ...]>
#   count=<liczba nowych bibliotek>
#   has_new=<"true"|"false">

set -euo pipefail

INDEX_FILE="index.json"
BASE_REV="${1:-}"
LIB_FILTER="${2:-}"

if [ ! -f "$INDEX_FILE" ]; then
  echo "::error::Nie znaleziono ${INDEX_FILE} w bieżącym katalogu" >&2
  exit 1
fi

flatten() {
  # index.json to tablica obiektów jednokluczowych: [{"name": "url"}, ...]
  jq -c '[ .[] | to_entries[] | {name: .key, url: .value} ]' "$1"
}

head_libs_json="$(flatten "$INDEX_FILE")"

if [ -n "$LIB_FILTER" ]; then
  # Tryb ręczny: zwróć tylko wskazaną bibliotekę, bez diffowania.
  new_libs_json="$(echo "$head_libs_json" | jq -c --arg n "$LIB_FILTER" \
    '[ .[] | select(.name == $n) ]')"
  if [ "$(echo "$new_libs_json" | jq 'length')" -eq 0 ]; then
    echo "::error::Biblioteka '${LIB_FILTER}' nie istnieje w ${INDEX_FILE}" >&2
    exit 1
  fi
else
  if [ -n "$BASE_REV" ] && git cat-file -e "${BASE_REV}:${INDEX_FILE}" 2>/dev/null; then
    base_libs_json="$(git show "${BASE_REV}:${INDEX_FILE}" | jq -c \
      '[ .[] | to_entries[] | {name: .key, url: .value} ]')"
  else
    echo "Uwaga: brak dostępnej bazowej wersji ${INDEX_FILE} (rev: '${BASE_REV:-<brak>}')." >&2
    echo "       Zakładam, że nie ma nowych bibliotek do przetestowania w tym uruchomieniu." >&2
    base_libs_json="$head_libs_json"
  fi

  new_libs_json="$(jq -c -n \
    --argjson head "$head_libs_json" \
    --argjson base "$base_libs_json" \
    '($base | map(.name)) as $basenames
     | [ $head[] | select(.name as $n | ($basenames | index($n)) == null) ]')"
fi

count="$(echo "$new_libs_json" | jq 'length')"

echo "Nowo dodane biblioteki w tym uruchomieniu: ${count}"
echo "$new_libs_json" | jq .

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "libs=${new_libs_json}"
    echo "count=${count}"
    if [ "$count" -gt 0 ]; then
      echo "has_new=true"
    else
      echo "has_new=false"
    fi
  } >> "$GITHUB_OUTPUT"
fi
