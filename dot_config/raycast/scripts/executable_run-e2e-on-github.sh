#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Run E2E on GitHub
# @raycast.mode compact

# @raycast.icon 🚀
# @raycast.packageName GitHub Automation

# Documentation:
# @raycast.description Runs end-to-end tests on GitHub by toggling the run_e2e label.
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

cd /Users/greg/Code/REDACTED_ORG/REDACTED_ORG

gh pr edit --remove-label run_e2e
gh pr edit --add-label run_e2e

echo "E2E tests triggered successfully on GitHub"
