#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Clear GitHub Notifications
# @raycast.mode fullOutput

# @raycast.icon 🔔
# @raycast.packageName GitHub Automation

# Documentation:
# @raycast.description Marks all GitHub notifications as read
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

# Initialize variables for pagination
page=1
per_page=100

while true; do
  echo "Processing page $page..."

  # Make a PUT request to the GitHub API to mark notifications as read
  response=$(gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "/notifications?page=$page&per_page=$per_page" \
    -f all=true)

  # Check if the response is empty (no more notifications)
  if [ "$response" == "[]" ]; then
    echo "All notifications marked as read."
    break
  else
    echo "Marked a batch of notifications as read. Continuing..."
  fi

  # Increment the page number for the next iteration
  page=$((page + 1))

  # Wait for 2 seconds before the next request to avoid hitting rate limits
  sleep 2
done
