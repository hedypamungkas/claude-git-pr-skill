#!/usr/bin/env bash
# Helper command: Calculate position in diff for a given file
# Usage: ./calculate-position.sh <pr_number> <file_path>
#
# Example:
#   ./calculate-position.sh 6 app/components/ProviderList.tsx
#
# This will show the diff with position numbers for easy reference

set -e

PR_NUMBER="${1:-}"
FILE_PATH="${2:-}"

if [ -z "$PR_NUMBER" ] || [ -z "$FILE_PATH" ]; then
  echo "Usage: $0 <pr_number> <file_path>"
  echo ""
  echo "Example:"
  echo "  $0 6 app/components/ProviderList.tsx"
  exit 1
fi

echo "Calculating positions for: $FILE_PATH in PR #$PR_NUMBER"
echo "========================================"
echo ""

# Get the diff for the specific file
gh pr diff "$PR_NUMBER" -- "$FILE_PATH" 2>/dev/null | awk '
BEGIN {
  position = 0
  in_hunk = 0
}

/^@@/ {
  # Extract the hunk header
  # Format: @@ -old_start,old_count +new_start,new_count @@
  # We need to track position from after this line
  hunk_start = NR + 1
  in_hunk = 1
  position = 1

  # Print the hunk header
  print $0
  next
}

in_hunk && /^[-+]/ {
  # Print with position number
  printf "Position %d: %s\n", position, $0
  position++
  next
}

in_hunk && /^ / {
  # Context line - still counts for position
  printf "Position %d: %s\n", position, $0
  position++
  next
}

in_hunk && /^$/ {
  # Empty line still counts
  printf "Position %d: (empty line)\n", position
  position++
  next
}

!in_hunk {
  # Print non-hunk lines as-is
  print
}
'
