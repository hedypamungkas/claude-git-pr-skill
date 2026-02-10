#!/usr/bin/env bash
# Helper command: Validate review JSON before posting
# Usage: ./validate-review.sh <pr_number> <json_file>
#
# Example:
#   ./validate-review.sh 6 /tmp/review_comments.json

set -e

PR_NUMBER="${1:-}"
JSON_FILE="${2:-}"

if [ -z "$PR_NUMBER" ] || [ -z "$JSON_FILE" ]; then
  echo "Usage: $0 <pr_number> <json_file>"
  echo ""
  echo "Example:"
  echo "  $0 6 /tmp/review_comments.json"
  exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
  echo "Error: File not found: $JSON_FILE"
  exit 1
fi

echo "Validating review for PR #$PR_NUMBER"
echo "===================================="
echo ""

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "Warning: jq not found. Skipping JSON validation."
  echo "Install jq for full validation: brew install jq"
  echo ""
else
  echo "1. Validating JSON structure..."
  if jq empty "$JSON_FILE" 2>/dev/null; then
    echo "   ✓ JSON is valid"
  else
    echo "   ✗ Invalid JSON"
    exit 1
  fi

  echo ""
  echo "2. Checking required fields..."

  # Check commit_id
  if jq -e '.commit_id' "$JSON_FILE" &> /dev/null; then
    echo "   ✓ commit_id present: $(jq -r '.commit_id' "$JSON_FILE")"
  else
    echo "   ✗ Missing commit_id"
    exit 1
  fi

  # Check comments array
  if jq -e '.comments | type == "array"' "$JSON_FILE" &> /dev/null; then
    COMMENT_COUNT=$(jq '.comments | length' "$JSON_FILE")
    echo "   ✓ comments array present: $COMMENT_COUNT comment(s)"
  else
    echo "   ✗ Missing or invalid comments array"
    exit 1
  fi

  echo ""
  echo "3. Validating each comment..."

  jq -c '.comments[]' "$JSON_FILE" | while read -r comment; do
    PATH=$(echo "$comment" | jq -r '.path // empty')
    POSITION=$(echo "$comment" | jq -r '.position // empty')
    BODY=$(echo "$comment" | jq -r '.body // empty')

    if [ -z "$PATH" ]; then
      echo "   ✗ Comment missing 'path' field"
      exit 1
    fi

    if [ -z "$POSITION" ] || [ "$POSITION" = "null" ]; then
      echo "   ✗ Comment on '$PATH' missing 'position' field"
      exit 1
    fi

    if ! echo "$POSITION" | grep -qE '^[0-9]+$'; then
      echo "   ✗ Comment on '$PATH' has invalid position: '$POSITION' (must be a number)"
      exit 1
    fi

    if [ -z "$BODY" ] || [ "$BODY" = "null" ]; then
      echo "   ✗ Comment on '$PATH' at position $POSITION missing 'body' field"
      exit 1
    fi

    echo "   ✓ $PATH:$POSITION - $(echo "$BODY" | head -c 40)..."
  done

  echo ""
  echo "4. Checking if files exist in PR diff..."

  # Get list of files in the PR diff
  PR_FILES=$(gh pr diff "$PR_NUMBER" --name-only 2>/dev/null | sort -u)

  jq -r '.comments[].path' "$JSON_FILE" | sort -u | while read -r path; do
    if echo "$PR_FILES" | grep -qxF "$path"; then
      echo "   ✓ $path found in PR diff"
    else
      echo "   ⚠ $path not found in PR diff (may have wrong path)"
    fi
  done
fi

echo ""
echo "===================================="
echo "Validation complete!"
echo ""
echo "Next step: Post the review"
echo "  gh api repos/:owner/:repo/pulls/$PR_NUMBER/reviews --input \"$JSON_FILE\""
