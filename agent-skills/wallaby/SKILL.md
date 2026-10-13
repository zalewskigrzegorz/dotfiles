---
name: wallaby
description: Write new tests step by step or improve existing test suites with Wallaby runtime evidence.
disable-model-invocation: true
---

Route the invocation before loading its reference:

- `$wallaby improve [scope and signal instructions]` selects [`references/improve.md`](references/improve.md).
- `$wallaby write [target or behavior instructions]` selects [`references/write.md`](references/write.md).

After routing, read [`wallaby-cli`](../wallaby-cli/SKILL.md) first. Then read the selected subcommand reference and follow its workflow. The subcommand reference determines when to perform discovery, start or query Wallaby, select targets, edit, and verify. Begin no task work until both files have been read.

Read only the additional Wallaby references required by the selected subcommand and the reports it produces.

For either subcommand, an explicit scope limits discovery, edits, and verification. Follow the selected workflow's scope rules when the invocation omits a target.
