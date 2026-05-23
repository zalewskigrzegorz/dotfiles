# TODO find the way to track performance in autoload modules

$env.config = (
    $env.config
    | upsert history {
        max_size: 100000
        sync_on_enter: true
        file_format: "sqlite"
        isolation: false
    }
)

$env.config.hooks.command_not_found = null

source autoload/vim.nu
source autoload/pay-respects.nu
