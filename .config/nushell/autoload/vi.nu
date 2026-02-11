export-env { $env.config = ($env.config | default {} | upsert edit_mode vi) }
