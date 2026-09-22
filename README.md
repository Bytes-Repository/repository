# Repository

Centralny rejestr bibliotek dla ekosystemu **H#** i menedżera
pakietów **bytes**. `index.json` to lista wpisów w formacie
`{"nazwa": "url-repozytorium"}` — każdy wpis wskazuje na osobne
repozytorium biblioteki, zawierające manifest `Bytes.hk`/`bytes.hk`.

## CI

Ten rejestr sam w sobie nie zawiera kodu H#, ale gdy do `index.json`
zostanie dodana nowa biblioteka, dwa workflowy automatycznie ją
weryfikują na świeżo pobranych, najnowszych binarkach `hsharp` i
`bytes` (pobieranych dynamicznie z ich najnowszych release'ów na
GitHubie — bez przypinania wersji na sztywno):

- **[`.github/workflows/tests.yml`](.github/workflows/tests.yml)** —
  wykrywa nowo dodane wpisy w `index.json`, klonuje wskazane
  repozytorium i uruchamia na nim `bytes build` + `bytes test`.
- **[`.github/workflows/build-packages.yml`](.github/workflows/build-packages.yml)** —
  to samo, ale buduje bibliotekę w trybie `bytes build --release` na
  kilku wersjach Ubuntu i publikuje wynik jako artefakt workflow.

Obydwa workflowy współdzielą skrypty pomocnicze w `.github/scripts/`:

- `detect-new-libs.sh` — diffuje `index.json` względem commita
  bazowego i zwraca listę nowo dodanych bibliotek.
- `install-hsharp-bytes.sh` — wykrywa najnowszy tag release'u
  `HackerOS-Linux-System/H-Sharp` i `Bytes-Repository/bytes`, pobiera
  i instaluje odpowiadające binarki `hsharp`/`bytes`.

Można też uruchomić dowolny z workflowów ręcznie (`workflow_dispatch`)
i wskazać jedną, konkretną bibliotekę do przetestowania/zbudowania
niezależnie od diffu.
