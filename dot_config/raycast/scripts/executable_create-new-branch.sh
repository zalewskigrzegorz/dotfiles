#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Create New Branch
# @raycast.mode fullOutput

# @raycast.icon 🌿
# @raycast.packageName GitHub Automation

# Documentation:
# @raycast.description Updates main branch and creates a new branch for a task
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

# @raycast.argument1 { "type": "dropdown", "placeholder": "Branch type", "prompt": "Select branch type", "required": true, "data": [{"title": "docs", "value": "docs"}, {"title": "feat", "value": "feat"}, {"title": "chore", "value": "chore"}, {"title": "fix", "value": "fix"}] }
# @raycast.argument2 { "type": "text", "placeholder": "Branch name", "prompt": "Enter branch name" }

# Change to the repository directory
cd /Users/greg/Code/Redocly/redocly || { echo "Failed to change directory"; exit 1; }

# Stash any existing changes
echo "Stashing any existing changes..."
git stash

# Update main branch
echo "Updating main branch..."
git checkout main
git pull origin main

# Create new branch
branch_type="$1"
branch_name="$2"
new_branch="${branch_type}/${branch_name}"

echo "Creating new branch: $new_branch"
git checkout -b "$new_branch"

if [ $? -eq 0 ]; then
    echo "Successfully created and switched to new branch: $new_branch"
else
    echo "Failed to create new branch"
    exit 1
fi

# Pop the stashed changes if there were any
if git stash list | grep -q "stash@{0}"; then
    echo "Applying stashed changes to the new branch..."
    git stash pop
fi
