# wife — Send clipboard contents to wife's Discord channel.
# Thin wrapper over `wife-send`. See bin/wife-send for behavior.
# Examples:
#   wife
#   wife "look at this"

def --env wife [note?: string] {
    if ($note | is-empty) {
        ^wife-send
    } else {
        ^wife-send --note $note
    }
}
