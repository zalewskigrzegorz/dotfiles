let limit = 20000

history
| last $limit
| reverse
| where {|row| ($row.command? | default "" | str trim | is-not-empty) }
| uniq-by command
| enumerate
| each {|row|
    let cmd = ($row.item.command | default "" | str replace -a "\n" "\\n")
    $"($row.index)\t($cmd)"
}
