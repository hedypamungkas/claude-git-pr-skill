#!/usr/bin/env bash
# Validate a single position in a file's diff
# Usage: ./validate-position.sh <pr_number> <file_path> <position>
#
# Example:
#   ./validate-position.sh 6 app/root.tsx 5
#
# Output:
#   ✅ Valid: Position 5 is in range [1-7]
#   OR
#   ❌ Invalid: Position 25 is out of range. Valid positions: [1-7]

set -e

PR_NUMBER="${1:-}"
FILE_PATH="${2:-}"
POSITION="${3:-}"

if [ -z "$PR_NUMBER" ] || [ -z "$FILE_PATH" ] || [ -z "$POSITION" ]; then
  echo "Usage: $0 <pr_number> <file_path> <position>"
  echo ""
  echo "Example:"
  echo "  $0 6 app/root.tsx 5"
  exit 1
fi

# Check if position is a valid number
if ! echo "$POSITION" | grep -qE '^[0-9]+$'; then
  echo "❌ Error: Position must be a positive integer, got '$POSITION'"
  exit 1
fi

# Get the diff for the specific file
DIFF_OUTPUT=$(gh pr diff "$PR_NUMBER" -- "$FILE_PATH" 2>/dev/null)

if [ -z "$DIFF_OUTPUT" ]; then
  echo "❌ Error: File '$FILE_PATH' not found in PR #$PR_NUMBER diff"
  echo ""
  echo "Available files in PR:"
  gh pr diff "$PR_NUMBER" --name-only 2>/dev/null | head -20
  exit 1
fi

# Calculate valid position ranges from diff hunks
# Format: @@ -old_start,old_count +new_start,new_count @@
MIN_POSITION=""
MAX_POSITION=""
HUNK_INFO=""

evaluate_hunks() {
  local position=0
  local hunk_start=0
  local in_hunk=0
  local hunk_min=0
  local hunk_max=0
  local first_hunk=1

  echo "$DIFF_OUTPUT" | awk '
  BEGIN {
    min_pos = ""
    max_pos = ""
    position = 0
    in_hunk = 0
  }

  /^@@/ {
    # New hunk starts at next line
    in_hunk = 1
    position = 1
    hunk_line = $0

    # Count lines in this hunk
    # Format: @@ -old_start,old_count +new_start,new_count @@
    # We need to find how many lines are in the NEW file (after the +)
    match($0, /\+([0-9]+),([0-9]+)/, arr)
    new_count = arr[2]

    hunk_min = (min_pos == "") ? position : min_pos
    hunk_max = position + new_count - 1

    if (min_pos == "" || position < min_pos) {
      min_pos = position
    }
    if (max_pos == "" || hunk_max > max_pos) {
      max_pos = hunk_max
    }

    print "HUNK:" hunk_line " RANGE:" position "-" hunk_max

    next
  }

  in_hunk && /^[-+ ]/ {
    position++
    next
  }

  in_hunk && /^$/ {
    position++
    next
  }

  END {
    print "MIN:" min_pos
    print "MAX:" max_pos
  }
  '
}

# Run evaluation and parse results
RESULT=$(evaluate_hunks)

# Parse the results
MIN_POSITION=$(echo "$RESULT" | grep "^MIN:" | cut -d: -f2)
MAX_POSITION=$(echo "$RESULT" | grep "^MAX:" | cut -d: -f2)
HUNK_INFO=$(echo "$RESULT" | grep "^HUNK:" | sed 's/HUNK:/  - /' | sed 's/ RANGE:/ -> positions /')

if [ -z "$MIN_POSITION" ] || [ -z "$MAX_POSITION" ]; then
  echo "⚠ Warning: Could not determine position range for '$FILE_PATH'"
  echo ""
  echo "Diff output:"
  echo "$DIFF_OUTPUT" | head -30
  exit 1
fi

# Check if position is in range
if [ "$POSITION" -ge "$MIN_POSITION" ] && [ "$POSITION" -le "$MAX_POSITION" ]; then
  echo "✅ Valid: Position $POSITION is in range [$MIN_POSITION-$MAX_POSITION]"
  echo ""
  echo "File: $FILE_PATH"
  echo "PR: #$PR_NUMBER"
  echo ""
  echo "Diff hunks:"
  echo "$HUNK_INFO"
  exit 0
else
  echo "❌ Invalid: Position $POSITION is out of range."
  echo ""
  echo "File: $FILE_PATH"
  echo "PR: #$PR_NUMBER"
  echo ""
  echo "Valid positions: [$MIN_POSITION-$MAX_POSITION]"
  echo ""
  echo "Diff hunks:"
  echo "$HUNK_INFO"
  echo ""
  echo "Suggested fixes:"
  echo "  1. Use calculate-position.sh to see all positions:"
  echo "     ./commands/calculate-position.sh $PR_NUMBER $FILE_PATH"
  echo ""
  echo "  2. Check the diff directly:"
  echo "     gh pr diff $PR_NUMBER -- $FILE_PATH"
  exit 1
fi
