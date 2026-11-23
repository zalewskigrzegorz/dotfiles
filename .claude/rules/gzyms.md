---
paths:
  - "dot_config/private_gzyms/**"
  - "run_onchange_after_49-gzyms-plugins.sh.tmpl"
  - "run_onchange_after_14-macos-defaults.sh.tmpl"
---

# Gzyms (menu bar, `dev.gzyms`, source `~/Code/personal/gzyms`)

- Stage 49 runs `gzyms plugin add` for the catalog plugins; their files stay untracked (Gzyms updates them). Greg's own plugins `pln-usd` and `pollen` are tracked under `private_plugins/`.
- **`config.toml.tmpl` is a template** since the Pollen plugin put a Homey token in it (`homey_id`/`homey_token` from 1Password `HOMEY_ID`/`HOMEY_TOKEN`). `chezmoi re-add` is a no-op on it and would leak the token as a plain file. After a change in Gzyms Settings: copy live into the template, keep the two `onepasswordRead` lines, then compare `chezmoi execute-template < <tmpl> | shasum` with `shasum < ~/.config/gzyms/config.toml`.
- Phone-push secrets live in the Keychain since Gzyms 0.0.4, seeded from 1Password `gzyms-phone-push`.
