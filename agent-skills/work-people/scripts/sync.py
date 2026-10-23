#!/usr/bin/env python3
"""Rebuild the work people matrix: full name ↔ GitHub login ↔ Slack ID.

Sources: GitHub org members (`gh`), Slack `users.list` (user token with
users:read + users:read.email). Writes a markdown table; a hand-kept overrides
TSV fixes the pairs the name matching cannot find.

  sync.py              rebuild and print the rows that are still unmatched
  sync.py --selftest   run the matching self-check, no network
"""
import json
import os
import re
import subprocess
import sys
import unicodedata
import urllib.request
from difflib import SequenceMatcher
from pathlib import Path

ORG = os.environ.get("WORK_GITHUB_ORG", "")
OUT_DIR = Path.home() / "Code/personal/bazgroly" / os.environ.get("WORK_GITHUB_ORG_LOWER", "work")
OUT = OUT_DIR / "people.md"
OVERRIDES = OUT_DIR / "people.overrides.tsv"


def norm(s):
    """Lowercase ASCII letters and single spaces: 'Bartłomiej  P.' -> 'bartlomiej p'."""
    s = (s or "").replace("ł", "l").replace("Ł", "L")
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = re.sub(r"\(.*?\)", " ", s)  # 'Jan Kowalski (Janek)'
    s = re.sub(r"[^a-zA-Z]+", " ", s)
    return " ".join(s.lower().split())


def is_full(name):
    return len(norm(name).split()) >= 2


def clean(name):
    name = re.sub(r"[​-‍﻿]", "", name or "")
    return " ".join(re.sub(r"\(.*?\)", " ", name).split())


def email_name(email):
    local = (email or "").split("@")[0]
    return " ".join(p.capitalize() for p in local.split(".")) if "." in local else ""


def slack_keys(u):
    p = u.get("profile", {})
    keys = {norm(p.get("real_name")), norm(p.get("display_name")),
            norm(f"{p.get('first_name', '')} {p.get('last_name', '')}"),
            norm(email_name(p.get("email"))), norm(u.get("name", "").replace(".", " "))}
    return {k for k in keys if k}


def full_name(gh_name, u):
    p = (u or {}).get("profile", {})
    mail = email_name(p.get("email"))
    for cand in (gh_name, p.get("real_name"), p.get("display_name"), mail,
                 (u or {}).get("name", "").replace(".", " ").title(),
                 re.sub(r"[-_]", " ", gh_name or "").title()):
        cand = clean(cand)
        if len(cand.split()) >= 2 and not re.search(r"[.\-_]", cand):
            # 'Kravchenko Anna' → 'Anna Kravchenko' when the e-mail has the same words
            if sorted(norm(cand).split()) == sorted(norm(mail).split()) != norm(cand).split():
                words = {norm(w): w for w in cand.split()}
                cand = " ".join(words[w] for w in norm(mail).split())
            return cand
    return clean(gh_name) or clean(p.get("real_name")) or ""


def match(gh, slack):
    """gh: [(login, name)], slack: [user dict]. Returns {login: slack user} for unique matches."""
    index = {}
    for u in slack:
        for k in slack_keys(u):
            index.setdefault(k, []).append(u)
    out, taken = {}, set()

    def unique(cands):
        ids = {u["id"] for u in cands}
        return cands[0] if len(ids) == 1 else None

    for login, name in gh:  # pass 1: exact name keys
        for k in (norm(name), norm(login.replace("-", " ").replace("_", " "))):
            u = unique(index.get(k, []))
            if k and u:
                out[login] = u
                break
    taken = {u["id"] for u in out.values()}
    for login, name in gh:  # pass 2: fuzzy on full names only
        if login in out or not is_full(name):
            continue
        a = norm(name).split()
        best = []
        for u in slack:
            if u["id"] in taken:
                continue
            for k in slack_keys(u):
                b = k.split()
                if len(b) < 2:
                    continue
                score = max(SequenceMatcher(None, " ".join(sorted(a)), " ".join(sorted(b))).ratio(),
                            SequenceMatcher(None, " ".join(a), " ".join(b)).ratio())
                prefix = a[0] == b[0] and len(a[-1]) >= 3 and b[-1].startswith(a[-1])
                if score >= 0.85 or prefix:
                    best.append(u)
                    break
        if len({u["id"] for u in best}) == 1:
            out[login] = best[0]
            taken.add(best[0]["id"])
    for login, _ in gh:  # pass 3: login vs e-mail ('annakowalska', 'NowakJ', typos like 'Gordiienko')
        if login in out:
            continue
        flat = norm(login).replace(" ", "")
        best = []
        for u in slack:
            local = (u.get("profile", {}).get("email") or "").split("@")[0].lower()
            surname = local.split(".")[-1] if "." in local else ""
            if u["id"] not in taken and (flat == local.replace(".", "") or (len(surname) >= 5 and (
                    surname in flat or SequenceMatcher(None, surname, flat).ratio() >= 0.85))):
                best.append(u)
        if len(best) == 1:
            out[login] = best[0]
            taken.add(best[0]["id"])
    return out


def fetch_github():
    q = ('query($endCursor:String){organization(login:"%s"){membersWithRole(first:100,after:$endCursor)'
         '{pageInfo{hasNextPage endCursor} nodes{login name}}}}' % ORG)
    raw = subprocess.run(["gh", "api", "graphql", "--paginate", "-f", f"query={q}",
                          "--jq", ".data.organization.membersWithRole.nodes[] | [.login, (.name // \"\")] | @tsv"],
                         check=True, capture_output=True, text=True).stdout
    return [tuple((line.split("\t") + [""])[:2]) for line in raw.splitlines() if line]


def fetch_slack():
    token = os.environ["WORK_SLACK_POSTER_TOKEN"]
    users, cursor = [], ""
    while True:
        req = urllib.request.Request(f"https://slack.com/api/users.list?limit=500&cursor={cursor}",
                                     headers={"Authorization": f"Bearer {token}"})
        data = json.load(urllib.request.urlopen(req, timeout=30))
        if not data.get("ok"):
            sys.exit(f"slack users.list: {data.get('error')} (needed: {data.get('needed')})")
        users += data["members"]
        cursor = data.get("response_metadata", {}).get("next_cursor", "")
        if not cursor:
            break
    team = os.environ.get("WORK_SLACK_TEAM_ID") or max(
        {u.get("team_id") for u in users}, key=lambda t: sum(u.get("team_id") == t for u in users))
    return [u for u in users if not u.get("deleted") and not u.get("is_bot")
            and u["id"] != "USLACKBOT" and u.get("team_id") == team]


def load_overrides():
    """login<TAB>slack_id[<TAB>full name]; slack_id '-' means 'no Slack account'."""
    rows = {}
    if OVERRIDES.exists():
        for line in OVERRIDES.read_text().splitlines():
            if line.strip() and not line.startswith("#"):
                parts = line.split("\t") + ["", ""]
                rows[parts[0].strip()] = (parts[1].strip(), parts[2].strip())
    return rows


def cell(s):
    return (s or "").replace("|", "/")


def main():
    if not ORG:
        sys.exit("WORK_GITHUB_ORG is not set (work.env not loaded)")
    gh, slack = fetch_github(), fetch_slack()
    by_id = {u["id"]: u for u in slack}
    pairs = match(gh, slack)
    overrides = load_overrides()
    rows, used, missing = [], set(), []
    for login, name in gh:
        sid, oname = overrides.get(login, ("", ""))
        u = by_id.get(sid) if sid else pairs.get(login)
        if sid and sid != "-" and not u:
            print(f"override {login} → {sid}: no such active Slack user", file=sys.stderr)
        if u:
            used.add(u["id"])
        elif sid != "-":
            missing.append(f"{login} ({name or 'no name'})")
        rows.append((oname or full_name(name, u), login, u["id"] if u else "", u))
    for u in slack:
        if u["id"] not in used:
            rows.append((full_name("", u), "", u["id"], u))
    rows.sort(key=lambda r: norm(r[0]))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        "# People — full name ↔ GitHub ↔ Slack",
        "",
        "Generated by `~/.claude/skills/work-people/scripts/sync.py`; don't edit rows here,",
        f"fix a wrong or missing pair in `{OVERRIDES.name}` and re-run.",
        "",
        "| Full name | GitHub | Slack ID | Slack name | Title |",
        "|---|---|---|---|---|",
    ]
    for full, login, sid, u in rows:
        p = (u or {}).get("profile", {})
        slack_name = clean(p.get("display_name") or p.get("real_name"))
        guest = " (guest)" if u and (u.get("is_restricted") or u.get("is_ultra_restricted")) else ""
        lines.append(f"| {cell(full)} | {f'`{login}`' if login else ''} | {f'`{sid}`' if sid else ''} "
                     f"| {cell(slack_name)}{guest} | {cell(p.get('title'))} |")
    OUT.write_text("\n".join(lines) + "\n")
    print(f"{OUT}: {len(rows)} people, {len(gh)} on GitHub, {len(slack)} on Slack")
    if missing:
        print(f"GitHub logins with no Slack match ({len(missing)}), add to {OVERRIDES}:")
        print("\n".join(f"  {m}" for m in missing))


def selftest():
    def u(i, real="", display="", email="", name=""):
        return {"id": i, "name": name, "profile": {"real_name": real, "display_name": display, "email": email}}
    slack = [u("U1", "jan.​kowalski", "Jan Kowalski", "jan.kowalski@x.com", "jan.kowalski"),
             u("U2", "Bartek", "Bartek", "bartlomiej.nowicki@x.com"),
             u("U3", "Roman Petrenkyy", "", "roman.petrenkyy@x.com"),
             u("U4", "Ivan", "Ivan", "ivan.melnychenko@x.com"),
             u("U5", "Ivan", "Ivan", "ivan.boyko@x.com"),
             u("U6", "Anna", "", "anna.kravchenko@x.com"),
             u("U7", "Stas", "", "stanislav.hordiienko@x.com")]
    got = {k: v["id"] for k, v in match([("kowalskij-x", "Jan Kowalski"), ("bnow", "Bartek"),
                                         ("rpet", "Roman Petrenkyi"), ("imel", "Ivan Mel."),
                                         ("anna-k", "Kravchenko Anna"), ("Gordiienko", "Stas G"),
                                         ("ghost", "")], slack).items()}
    assert got == {"kowalskij-x": "U1", "bnow": "U2", "rpet": "U3", "imel": "U4", "anna-k": "U6",
                   "Gordiienko": "U7"}, got
    assert full_name("Jan Kowalski (Janek)", None) == "Jan Kowalski"
    assert full_name("Bartek", slack[1]) == "Bartlomiej Nowicki"
    assert full_name("", slack[0]) == "Jan Kowalski"
    assert full_name("Kravchenko Anna", slack[5]) == "Anna Kravchenko"
    assert full_name("olena-shevchuk", u("U8", "Olena", "", "olena@x.com")) == "Olena Shevchuk"
    print("selftest ok")


if __name__ == "__main__":
    selftest() if "--selftest" in sys.argv else main()
