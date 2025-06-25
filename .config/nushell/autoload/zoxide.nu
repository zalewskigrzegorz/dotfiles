# Zoxide - Smart directory navigation
# Provides 'z' command for jumping to frequently used directories

let zoxide_path = ($nu.data-dir | path join "vendor/autoload/zoxide.nu")
mkdir ($zoxide_path | path dirname)
zoxide init nushell | save -f $zoxide_path 