---
name: pr-changes-data
description: Pobiera dane o zmianach w PR (metadane, pliki, diff) w celu dalszych operacji — odniesienia do zmian, inteligentny port na inny branch z dostosowaniem do stanu brancha i konfliktów. Nie służy do code review. Use when user wants PR change data for porting, referencing, or applying changes to another branch.
---

# PR Changes Data

Skill do **pobierania danych o zmianach w PR** i **operowania na nich**: odniesienia w rozmowie, inteligentny port zmian na inny branch (z uwzględnieniem konfliktów i obecnego stanu brancha). **Nie jest to skill do code review** — dane są surowcem do dalszych akcji.

## Kiedy używać

- Użytkownik chce mieć "dane z PR" do późniejszego użycia (odniesienie, port, analiza).
- Użytkownik chce przenieść zmiany z PR na inny branch **inteligentnie** (dostosowanie do stanu brancha, konflikty), a nie przez zwykły cherry-pick.
- Użytkownik mówi o "snapshot PR", "dane z PR", "port zmian", "przenieś zmiany na branch X".

## Część 1 — Pobieranie danych PR

Cel: uzyskać ustrukturyzowany zestaw danych o zmianach, który można później cytować lub użyć do portu.

### Źródła danych

**GH CLI (preferowane gdy repo jest lokalnie):**
- Metadane: `gh pr view <PR> --json number,title,url,author,baseRefName,headRefName,additions,deletions,changedFiles,files,commits`
- Lista plików: z `files` w JSON lub `gh pr diff <PR> --name-only`
- Diff: `gh pr diff <PR>` (pełny) lub `gh pr diff <PR> --patch` (z patchami)
- Opcjonalnie skrypt: `agent-skills/gh-smart-port/scripts/pr_snapshot.sh <PR>` — zwraca meta + diffstat + początek diffu

**GitHub MCP (gdy potrzebny dostęp przez API):**
- `get_pull_request` — owner, repo, pull_number → szczegóły PR
- `get_pull_request_files` — lista zmienionych plików (path, status, patch itd.)
- Dla treści plików: `get_file_contents` po odpowiednim ref (np. head ref PR)

**Git (gdy masz branch PR lokalnie):**
- `git diff <baseRef>..<headRef>` — diff między base a head PR
- `git diff --name-status`, `git diff --stat`

### Format danych do zachowania / przekazania dalej

Przygotuj zwięzły "snapshot" w formie nadającej się do operacji:

- **Meta**: numer PR, tytuł, base branch, head branch, autor, additions/deletions, liczba plików.
- **Pliki**: ścieżki + status (added/modified/deleted/renamed).
- **Intencja zmian**: 1–2 zdania streszczenia "co PR robi" (na podstawie tytułu, plików, diff).
- **Obszary**: które moduły/pliki/API są dotknięte (lista).
- **Diff**: pełny lub skrócony — w zależności od limitu kontekstu; dla portu przydatny pełny diff lub patch per plik.

Można zapisać snapshot do pliku (np. `pr-<number>-snapshot.md` lub `.json`) w repo, jeśli użytkownik chce go użyć w kolejnych krokach.

## Część 2 — Operacje na danych

### 2.1 Odniesienie do zmian

Na podstawie snapshotu możesz:
- Odpowiadać na pytania typu "co zmienia ten PR w pliku X?", "które pliki dotykają API?"
- Cytować konkretne fragmenty diffu (plik, zakres linii, przed/po).
- Podsumować "co już jest w PR" przed decyzją o porcie.

### 2.2 Inteligentny port zmian na inny branch

**Cel:** przenieść zmiany z PR (lub brancha źródłowego) na **target branch**, dostosowując je do **obecnego stanu** targetu — w tym rozwiązanie konfliktów, bez polegania na prostym `git cherry-pick` (chyba że użytkownik wyraźnie go zażyczy).

**Kroki:**

1. **Źródło i target**  
   Określ: branch/PR źródłowy (np. head ref PR) i docelowy branch (np. `main`, `release/x`).

2. **Snapshot źródła**  
   Użyj Części 1; miej listę plików i diff (lub patch).

3. **Stan targetu**  
   Na target branchu: które z tych plików istnieją, czy się zmieniły względem base PR.  
   Przydatne: `git diff <base-ref>..<target-branch> -- <path>` dla wybranych ścieżek, `git status`, ewentualnie `git merge-base`.

4. **Strategie portu (wybór w zależności od sytuacji)**  
   - **Port po plikach** — gdy zmiany są spójne per plik i mało konfliktów:  
     `git checkout <target>`, potem `git checkout <source-ref> -- <path>` dla wybranych plików; ewentualnie `git add -p` do selekcji hunków.  
   - **Port po patchach / hunki** — gdy chcesz przenieść tylko fragmenty:  
     Zapisany diff z PR zastosować na target: `git apply` (lub `git apply -3` przy konfliktach 3-way), potem ręczne dopracowanie.  
   - **Port commitów** — tylko na wyraźną prośbę:  
     `git cherry-pick` / `git cherry-pick -n`; przy konfliktach — rozwiązanie, potem `git add` i `git cherry-pick --continue`.

5. **Konflikty**  
   Przy `git apply -3` lub `git checkout <ref> -- <path>` konflikty mogą wymagać ręcznego połączenia. Opisz użytkownikowi: które pliki kolidują, co w nich jest (np. "ta sama funkcja zmieniona w obu branchach") i zaproponuj konkretne miejsca do edycji lub krótkie instrukcje "co zostawić / co scalić".

6. **Po porcie**  
   Podaj checklistę: build, testy, smoke; ewentualnie `git diff <target>..HEAD` żeby pokazać, co faktycznie zostało dodane na target.

W raporcie portu podaj: które pliki/hunki przenosisz i dlaczego, gdzie są ryzyka konfliktów, oraz krótkie kroki do wykonania (komendy + ewentualne miejsca do ręcznej edycji).

## Zasady

- **Nie publikuj** nic na GitHubie (komentarze, review) bez wyraźnej prośby.
- **Nie rób** destrukcyjnych operacji (force push, merge do main, zamykanie PR) bez wyraźnej instrukcji.
- Najpierw **pobierz dane** (snapshot), potem wykonuj lub proponuj **operacje** (odniesienia, port).
- Ten skill **nie zastępuje code review** — nie ocenia jakości kodu; dostarcza dane i procedury do pracy na zmianach.
