#!/bin/zsh
# thread-clean.sh <message-id> — `spark thread` with quoted history, signatures
# and mail-footer boilerplate stripped, so a long dealer/bank thread reads as
# the new text only. Attachments lines are kept.
#
# The same rg -v chain was hand-written ~24 times in one session (2026-09-29).
set -u
[ $# -ge 1 ] || { echo "usage: thread-clean.sh <message-id>" >&2; exit 2; }
spark thread "$1" | python3 -c '
import re, sys
sig = re.compile(r"^\s*(--\s*$|__+\s*$|Pozdrawiam|Z poważaniem|Z wyrazami szacunku|Best regards|Kind regards|Regards,|Sent from my|Wysłane z)", re.I)
noise = re.compile(r"^\s*(>|Otrzymany mail|NIP[: ]|REGON|KRS|Sąd Rejonowy|T\s*\+48|Tel\.? ?\+?48|ul\. |Al\. |Ten e-?mail|This e-?mail|Wiadomość ta|Please consider the environment)", re.I)
header = re.compile(r"^(From|Od|Date|Data|Subject|Temat|To|Do|Attachments?|Załączniki?)\s*:", re.I)
sep = re.compile(r"^(={5,}|-{5,}|Message \d+|#{2,}|── )")
in_sig = False
for line in sys.stdin:
    line = line.rstrip("\n")
    if sep.match(line) or header.match(line):
        in_sig = False
        print(line); continue
    if in_sig: continue
    if sig.match(line):
        in_sig = True; continue
    if noise.match(line): continue
    print(line)
'
