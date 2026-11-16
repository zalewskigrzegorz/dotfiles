---
paths:
  - "dot_config/private_karabiner/**"
---

# Karabiner (`dot_config/private_karabiner/karabiner.json`)

- **Flow:** edit the live `~/.config/karabiner/karabiner.json`. Karabiner reloads it by itself (`tail /var/log/karabiner/core_service.log`), then `chezmoi re-add` it.
- **Add a rule with `Edit`, keeping the indentation, never `jq '… += […]'`.** `jq` reformatted the whole file (a diff of hundreds of lines instead of ~20). After the edit `git diff --stat -- <file>` shows only added lines, otherwise restore with `git show HEAD:<file>` and insert by hand. Validate with `jq -e '.profiles[0].complex_modifications.rules | length'`.
- **A turned-on Caps Lock counts as a held modifier.** A rule `from: caps_lock` with `mandatory: ["caps_lock"]` broke the tap, so the tuios leader stopped working. A `simultaneous` rule on both Shifts needs `modifiers.optional: ["any"]`. To switch Caps Lock off for sure use `IOHIDSetModifierLockState` from `ctypes`. `to_if_held_down` takes `"repeat": false`.
- **Changing a rule that worked:** test its original behaviour first (tap and hold), then the new one. No changes "while at it".
