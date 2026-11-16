#!/bin/bash
# Gzyms repo watcher: what others do around your repos (PRs, issues, discussions, forks, sponsors). Stars stay with
# the built-in star watcher. Built on its loop. Options arrive as GZYMS_OPT_<KEY>; Bash 3.2, gh and jq.
# The last seen state lives in a cache file: something that came while Gzyms was off still pings on the next start.
PILL=repo ICON=tray
JQ="$(command -v jq || echo /usr/bin/jq)"
: "${GZYMS_OPT_EVERY:=300}"
decl="" sel="" vars=() rp='[]' i=0
NEWEST='first:10,orderBy:{field:CREATED_AT,direction:DESC}'
ITEM='number title url state author{login}'
while IFS= read -r r; do
  r="${r#"${r%%[![:space:]]*}"}"; r="${r%"${r##*[![:space:]]}"}"
  [[ "$r" =~ ^([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)$ ]] || continue
  # Names go in as GraphQL variables, never into the query text.
  decl+=" \$o${i}:String! \$n${i}:String!"
  sel+=" r${i}:repository(owner:\$o${i},name:\$n${i}){forkCount
    forks($NEWEST){nodes{nameWithOwner url owner{login}}}
    pullRequests($NEWEST){nodes{$ITEM}} issues($NEWEST){nodes{$ITEM}}
    openPrs:pullRequests(states:OPEN,first:20,orderBy:{field:CREATED_AT,direction:DESC}){nodes{$ITEM}}
    openIssues:issues(states:OPEN,first:20,orderBy:{field:CREATED_AT,direction:DESC}){nodes{$ITEM}}
    discussions($NEWEST){nodes{number title url author{login} comments{totalCount}}}}"
  vars+=(-f "o$i=${BASH_REMATCH[1]}" -f "n$i=${BASH_REMATCH[2]}")
  rp=$("$JQ" -c --argjson i $i --arg repo "$r" '. + [{i: $i, repo: $repo}]' <<< "$rp")
  i=$((i + 1))
done <<< "${GZYMS_OPT_REPOS:-}"
if [ -z "$sel" ]; then
  echo '{"item":{"id":"repo","text":"set a repo","icon":"tray","color":"overlay","tooltip":"Settings → Plugins → Repo watcher → Repos"}}'
  exec cat >/dev/null
fi
SPONSORS='viewer{login sponsorshipsAsMaintainer(first:50,orderBy:{field:CREATED_AT,direction:DESC}){totalCount nodes{sponsorEntity{... on User{login} ... on Organization{login}}}}}'
ARGS=(-f "query=query($decl){$SPONSORS $sel}" "${vars[@]}")
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/gzyms/repo-watcher.json"
mkdir -p "$(dirname "$CACHE")"
STATE0=$("$JQ" -c '{base: (if type == "object" then . else {} end)}' "$CACHE" 2>/dev/null)
JQARGS=(--argjson repos "$rp")

# Modes: poll (stdin = GitHub's answer), error, render. base = what the last answer left: per repo the highest
# PR/issue/discussion number (they share one counter) and the forks seen; "@sponsors" = the sponsor logins seen.
read -r -d '' PROG <<'JQ'
def who: .author.login // "ghost";
def notify: {notify: {id: "repo-\(.repo)-\(.id)", title: {pr: "New PR", issue: "New issue", disc: "New discussion",
  fork: "New fork", sponsor: "New sponsor"}[.k], subtitle: .repo, body: .body, link: .url, level: "info", sound: "message"}};
def stat($st): ([$ENV.GZYMS_OPT_EVERY // "" | tonumber?][0]) as $e | (if $e then {expect: $e} else {} end) + (if $st.err then {error: $st.err} else {} end);
def render($st):
  if $st.view == null then {item: ({id: "repo", text: "…", icon: "tray", color: "overlay", tooltip: "Asking GitHub…"}
      + (if $st.err then {} else {menu: [{text: "Asking GitHub…"}]} end) + stat($st))}
  else
    ([$st.view.repos[].open[]] | length) as $t
    | {item: ({id: "repo", text: "\($t)", icon: (if $t > 0 then "tray.full.fill" else "tray" end),
        color: (if $t > 0 then "gold" else "overlay" end), tooltip: "\($t) open PRs and issues from others",
        menu: ([$st.view.repos[] | {text: .repo, detail: ":arrow.triangle.branch: \(.forkCount)"},
                 (if (.open | length) == 0 then {text: "Nothing open from others"} else .open[] end), .disc[], {separator: true}]
          + [{text: "Sponsors", detail: ":heart.fill@red: \($st.view.sponsors // "?")"}])} + stat($st))}
  end;
if $mode == "poll" then
  . as $r
  | ($r.data.viewer.login // "") as $me
  | [$repos[] | .repo as $repo | ($r.data["r\(.i)"] // null) as $o | select($o != null)
     | {repo: $repo, forkCount: $o.forkCount,
        new: ([$o.pullRequests.nodes[] | {k: "pr", n: .number, id: "pr\(.number)", url, who: who, body: "#\(.number) \(.title), from \(who)"}]
            + [$o.issues.nodes[] | {k: "issue", n: .number, id: "i\(.number)", url, who: who, body: "#\(.number) \(.title), from \(who)"}]
            + [$o.discussions.nodes[] | {k: "disc", n: .number, id: "d\(.number)", url, who: who, body: "#\(.number) \(.title), from \(who)"}]),
        forks: [$o.forks.nodes[] | {k: "fork", id: .nameWithOwner, url, who: .owner.login, body: "\(.nameWithOwner)"}],
        open: ([$o.openPrs.nodes[] | select(who != $me) | {id: .url, tag: "PR", color: "peach", text: "#\(.number) \(.title)", detail: who}]
             + [$o.openIssues.nodes[] | select(who != $me) | {id: .url, tag: "issue", color: "sky", text: "#\(.number) \(.title)", detail: who}]),
        disc: [$o.discussions.nodes[:3][] | {id: .url, tag: "talk", color: "mauve", text: "#\(.number) \(.title)", detail: ":bubble.left: \(.comments.totalCount)"}]}] as $got
  | ($st.base // {}) as $b
  # a repo with nothing in the cache is the baseline: a first start tells nothing
  | [$got[] | .repo as $repo | ($b[$repo] // null) as $old | select($old != null)
     | ((.new[] | select(.n > ($old.top // 0))), (.forks[] | .id as $f | select(any(($old.forks // [])[]; . == $f) | not)))
     | select(.who != $me) | . + {repo: $repo}] as $news
  | ($r.data.viewer.sponsorshipsAsMaintainer // null) as $sp
  | [$sp.nodes[]? | .sponsorEntity.login // empty] as $sl
  | (if $sp != null and $b["@sponsors"] != null
     then [$sl[] | . as $l | select(any($b["@sponsors"][]; . == $l) | not)
       | {k: "sponsor", id: "s-\($l)", repo: "GitHub Sponsors", url: "https://github.com/\($l)", body: "\($l) sponsors you now."}]
     else [] end) as $snews
  | ($b + ($got | map({(.repo): {top: ([.new[].n, ($b[.repo].top // 0)] | max),
        forks: ([.forks[].id] + ($b[.repo].forks // []) | unique)}}) | add // {})
     + (if $sp != null then {"@sponsors": ($sl + ($b["@sponsors"] // []) | unique)} else {} end)) as $nb
  | ($st + {base: $nb, view: {repos: [$got[] | {repo, forkCount, open, disc}], sponsors: ($sp.totalCount // $st.view.sponsors)}, err: null}) as $s
  | $s, (($news + $snews)[] | notify), render($s)
elif $mode == "error" then ($st + {err: $err}) as $s | $s, render($s)
else $st, render($st) end
JQ

GH="${GH_BIN:-$(command -v gh || { [ -x /opt/homebrew/bin/gh ] && echo /opt/homebrew/bin/gh; } || echo /usr/local/bin/gh)}"
every="${GZYMS_OPT_EVERY:-300}"; case "$every" in ''|*[!0-9]*|0) every=300;; esac
export GZYMS_OPT_EVERY=$every  # the jq program promises it as the pill's expect
problem() {  # pill text, sentence: a greyed pill that says what is missing, then wait for Gzyms to go
  echo "{\"item\":{\"id\":\"$PILL\",\"text\":\"$1\",\"icon\":\"$ICON\",\"error\":\"$2\"}}"
  exec cat >/dev/null
}
[ -x "$GH" ] || problem "install gh" "Install the GitHub CLI (brew install gh), then turn this plugin off and on."

state="${STATE0:-}"; [ -n "$state" ] || state='{}'
asked=-99 clockpid=""
step() {  # mode [err], stdin = GitHub's answer or null. Prints the new state's lines, keeps the state.
  local out l
  out=$("$JQ" -c --arg mode "$1" --arg err "${2:-}" --argjson st "$state" "${JQARGS[@]}" "$PROG") || return
  { IFS= read -r state
    while IFS= read -r l; do
      case "$l" in ?*) echo "$l";; esac
    done; } <<< "$out"
  if [ "$1" = poll ]; then "$JQ" -c '.base // {}' <<< "$state" > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"; fi
}

clock() {  # R <answer> after a good call, X auth|rate|net after a bad one. USR1 = ask now. Errors double the wait, up to 15 min.
  local pause=$every res ok sp=""
  trap 'kill $sp 2>/dev/null' USR1
  trap 'kill $sp 2>/dev/null; exit 0' TERM
  while :; do
    res=$("$GH" api graphql "${ARGS[@]}" 2>/dev/null)
    # A partial answer (one repo of the list gone) still has data: use it.
    ok=$(printf '%s' "$res" | "$JQ" -c 'select(.data | type == "object")' 2>/dev/null)
    if [ -n "$ok" ]; then
      printf 'R %s\n' "$ok"; pause=$every
    else
      case "$res" in
        *[Rr]ate\ limit*|*RATE_LIMITED*) echo "X rate";;
        *"Bad credentials"*) echo "X auth";;
        *) if "$GH" auth token >/dev/null 2>&1; then echo "X net"; else echo "X auth"; fi;;
      esac
      pause=$((pause * 2 > 900 ? 900 : pause * 2))
    fi
    sleep "$pause" & sp=$!
    wait $sp
  done
}

on_event() {
  local ev id
  IFS=$'\x1f' read -r ev id <<< "$(printf '%s' "$1" | "$JQ" -r '[.event // "", .id // ""] | join("\u001f")')"
  if [ "$ev" = open ]; then  # the list opened: a fresh look unless one ran 15 s ago
    [ -n "$clockpid" ] && [ $((SECONDS - asked)) -ge 15 ] && kill -USR1 "$clockpid" 2>/dev/null && asked=$SECONDS
    return
  fi
  [ "$ev" = click ] && case "$id" in https://github.com/*) open "$id";; esac
}

# One stream of three: P = the clock's pid, R/X = GitHub, E = an event from Gzyms. Stdin ends: the clock goes too.
{
  echo S
  clock & c=$!
  echo "P $c"
  while IFS= read -r e; do printf 'E %s\n' "$e"; done
  kill $c 2>/dev/null
} | while IFS= read -r msg; do
  case "$msg" in
    S) step render <<< null;;
    "P "*) clockpid=${msg#P };;
    "R "*) step poll <<< "${msg#R }";;
    "X auth") step error "gh is logged out. Run gh auth login in a terminal. This pill updates by itself after that." <<< null;;
    "X rate") step error "GitHub's rate limit is reached. Asking less often for a while." <<< null;;
    "X net") step error "GitHub did not answer. Check the network. Trying again." <<< null;;
    "E "*) on_event "${msg#E }";;
  esac
done
