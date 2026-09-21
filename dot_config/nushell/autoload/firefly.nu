# Firefly III — historia z Moje ING do Firefly jedną komendą.
#
#   firefly                        # najnowsze Lista_transakcji_nr_*.csv z ~/Downloads
#   firefly ~/Downloads/a.csv …    # konkretne eksporty
#   firefly --dry                  # tylko konwersja + podgląd, nic nie leci na lab
#   firefly --all                  # bez pytania, wysyła wszystkie konta
#
# Co robi po kolei:
#   1. ing-csv.py — prostuje eksport ING (preambuła, układ kolumn, blokady
#      kartowe, przelewy własne) i tnie go na plik per konto
#   2. pyta, które konta wysłać (spacja = zaznacz, a = wszystko, enter = ok)
#   3. scp na lab do data/firefly-importer/import (config mapowania też)
#   4. php artisan importer:import w kontenerze, osobno dla każdego pliku
#
# Duplikaty biorą się na siebie same: ing-pl.json mapuje kolumnę tx_id na
# external-id i ma duplicate_detection_method=cell, więc zachodzące na siebie
# eksporty są bezpieczne. Dat przy eksporcie nie trzeba pilnować — bierz
# z zapasem.
#
# Config w repo (home-lab/data/firefly-importer/import/ing-pl.json) jest
# źródłem prawdy i przy każdym uruchomieniu nadpisuje ten na labie. Jeśli
# poprawisz mapowanie w kreatorze importera, pobierz nowy JSON i wrzuć do repo.

def firefly [
    ...files: path    # eksporty z Moje ING; puste = najnowsze z ~/Downloads
    --dry             # tylko konwersja, nic nie wysyła
    --all             # nie pytaj, wyślij wszystkie konta
] {
    let repo = ([$env.HOME Code home-lab] | path join)
    let script = ([$repo services firefly-importer bin ing-csv.py] | path join)
    let config = ([$repo data firefly-importer import ing-pl.json] | path join)
    let remote = "/opt/homelab/data/firefly-importer/import"

    for f in [$script $config] {
        if not ($f | path exists) {
            print $"(ansi red)brak ($f)(ansi reset)"
            return
        }
    }

    let sources = if ($files | is-empty) {
        glob ([$env.HOME Downloads "Lista_transakcji_nr_*.csv"] | path join)
    } else {
        $files
    }
    if ($sources | is-empty) {
        print $"(ansi red)brak eksportów w ~/Downloads(ansi reset)"
        print "Moje ING → Historia → ⋮ → Pobierz historię do pliku → CSV"
        print "Profil prywatny i firmowy eksportujesz osobno."
        return
    }

    let out = (mktemp -d -t "firefly-import-XXXXXX")
    print $"(ansi cyan)→ konwersja(ansi reset) ($sources | length) — eksporty z ING"
    $sources | each {|f| print $"    ($f | path basename)" }
    ^python3 $script ...$sources -o $out --split

    let converted = (glob $"($out)/*.csv")
    if ($converted | is-empty) {
        print $"(ansi red)konwersja nie dała żadnego pliku(ansi reset)"
        return
    }

    let plan = $converted | each {|f|
        let rows = (open --raw $f | from csv)
        let dates = ($rows | get date | sort)
        {
            konto: ($f | path basename | str replace -r '^ing-' '' | str replace '.csv' '')
            transakcje: ($rows | length)
            od: ($dates | first)
            do: ($dates | last)
            plik: ($f | path basename)
        }
    } | sort-by transakcje --reverse

    if $dry {
        print $"(ansi yellow)--dry(ansi reset) — wynik w ($out), nic nie wysłano:"
        print ($plan | reject plik)
        return
    }

    let picked = if $all {
        $plan | reject plik
    } else {
        print ""
        print $"(ansi cyan)Co wysłać do Firefly?(ansi reset)  spacja = zaznacz, a = wszystko, enter = potwierdź"
        ($plan | reject plik | input list --multi)
    }

    if ($picked | is-empty) {
        print $"(ansi yellow)nic nie wybrano(ansi reset) — pliki zostały w ($out)"
        return
    }

    let kont = ($picked | get konto)
    let chosen = ($plan | where konto in $kont)
    let payload = ($chosen | each {|it| ([$out $it.plik] | path join) })

    print $"(ansi cyan)→ wysyłka na lab(ansi reset)"
    ^scp $config ...$payload $"lab:($remote)/"

    print $"(ansi cyan)→ import(ansi reset)"
    for it in $chosen {
        print $"    ($it.konto) — ($it.transakcje) transakcji"
        ^ssh lab $"docker exec firefly-importer php artisan importer:import /import/ing-pl.json /import/($it.plik)"
    }

    print $"(ansi green)gotowe(ansi reset) → https://firefly.mrglaszki.com/"
}
