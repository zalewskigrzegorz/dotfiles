---
name: gh-smart-port
description: GH CLI workflow: (1) snapshot zmian z PR/brancha, (2) review PR z mapą ryzyk bez publikowania komentarzy, (3) inteligentny port zmian na inny branch (bez cherry-pick jako default).
disable-model-invocation: true
version: 0.1.0
---

# GH Smart Port + PR Attention Review (no auto comments)

## Zasady bezpieczeństwa / zachowania
1) NIGDY nie publikuj komentarzy ani review na GitHubie automatycznie.
    - Nie uruchamiaj: `gh pr comment`, `gh pr review`, `gh api` do tworzenia komentarzy.
    - Raport pokazuj lokalnie w odpowiedzi czatu (albo zapisuj do pliku w repo jeśli poproszę).
2) Nie rób destrukcyjnych operacji bez wyraźnej instrukcji użytkownika:
    - nie `push --force`, nie merge do `main`, nie zamykaj PR, nie zmieniaj ustawień repo.
3) Najpierw ZAWSZE zrób snapshot (kontekst), potem czekaj na instrukcje "co trzeba zrobić".

## Część A — Snapshot PR (czytanie zmian)
Jeśli użytkownik poda numer/URL PR:
-  Pobierz metadane PR: tytuł, base/head, listę plików, autorów/commits.
-  Pobierz diff PR i statystyki zmian.
-  Zrób streszczenie "intencji zmian" + lista obszarów dotkniętych zmianami (moduły, pliki, API, migracje).

Preferowane komendy (przykłady):
-  `gh pr view <PR> --json title,number,author,baseRefName,headRefName,additions,deletions,changedFiles,files,commits,url`
-  `gh pr diff <PR>`
-  (opcjonalnie) `gh pr checks <PR>`

## Część B — PR Attention Review (bez komentowania)
Na bazie diffu i listy plików przygotuj raport "co warto obejrzeć", bez wstawiania komentarzy do PR.

Wyjście ma mieć sekcje:
-  **High-risk hotspots**: max 10 punktów, każdy z: plik, zakres (jeśli da się), dlaczego ryzykowne, co sprawdzić.
-  **Correctness**: potencjalne bugi, warunki brzegowe, regresje.
-  **Security & data**: tokeny/sekrety, PII, uprawnienia, walidacja inputu, zapytania do DB.
-  **Testing**: co jest pokryte, czego brakuje (konkretnie: które ścieżki kodu).
-  **Maintainability**: zbyt duży diff, duplikacje, nazewnictwo, coupling, publiczne API.
-  **Questions to ask author**: max 5 krótkich pytań.

## Część C — Inteligentny port zmian (bez cherry-pick jako default)
Cel: przenieść "intencję" zmian z PR/brancha na inny branch, ale selektywnie i świadomie.

Zawsze:
1) Zidentyfikuj źródło zmian (PR / branch) i target branch.
2) Zrób snapshot zmian źródła.
3) Zaproponuj plan portu jako 2–3 strategie, z plusami/minusami i komendami.

Strategie (wybieraj w zależności od sytuacji):
-  **Strategia 1: Port plików** (gdy zmiany są spójne per plik):
    - użyj `git restore -s <source> -- <paths>` aby przenieść wersje plików,
    - potem selekcja hunków: `git add -p`,
    - na koniec dopracowanie ręczne.
-  **Strategia 2: Port hunków / patchy** (gdy chcesz wybrać tylko fragmenty):
    - bazuj na `gh pr diff` / `git diff <base>..<source>` i ręcznej selekcji,
    - ewentualnie `git apply -3` dla konfliktów 3-way.
-  **Strategia 3: Port commitów** (tylko jeśli użytkownik wyraźnie chce commit-level):
    - `git cherry-pick` lub `git cherry-pick -n` (ale to nie jest domyślne).

W raporcie portu podaj:
-  które pliki/hunki przenosisz i dlaczego,
-  ryzyka konfliktów,
-  checklistę "po porcie": build, testy, smoke.

## Minimalny "GH CLI quickref" (dla użytkownika)
-  Checkout PR lokalnie: `gh pr checkout <PR>` (działa też po branch name/URL).
-  Lista PR: `gh pr list`
-  Podgląd PR: `gh pr view <PR>`
-  Diff PR: `gh pr diff <PR>`
