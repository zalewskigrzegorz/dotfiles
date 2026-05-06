let limit = 20000

history
| last $limit
| reverse
| where {|row| ($row.command? | default "" | str trim | is-not-empty) }
| uniq-by command
| each {|row|
    $row.command
    | default ""
    | str replace -a "\n" "\\n"
}
| str join "\n"
