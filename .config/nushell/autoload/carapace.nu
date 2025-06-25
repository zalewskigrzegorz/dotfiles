# Carapace - Enhanced completions
# Provides better command completions for various CLI tools

let carapace_dir = ($env.HOME | path join ".cache" "carapace")
mkdir $carapace_dir
carapace _carapace nushell | save --force ($carapace_dir | path join "init.nu") 