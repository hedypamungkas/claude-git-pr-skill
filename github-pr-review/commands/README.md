# Helper Commands

This directory contains helper commands to make PR reviews easier and more reliable.

## Available Commands

### calculate-position.sh

Calculate position numbers in the diff for a given file. This helps you find the correct position values to use in your review comments.

**Usage:**
```bash
./commands/calculate-position.sh <pr_number> <file_path>
```

**Example:**
```bash
./commands/calculate-position.sh 6 app/components/ProviderList.tsx
```

**Output:**
```
Calculating positions for: app/components/ProviderList.tsx in PR #6
========================================

@@ -1,9 +1,19 @@
Position 1: import { Link } from "react-router";
Position 2: (empty line)
Position 3: import ekaHospitalImage ...
Position 4: import heroImage ...
...
Position 9: import pondokIndahImage ...  ← Use position 9 in your review
Position 10: import siloamImage ...      ← Use position 10 in your review
```

### validate-review.sh

Validate a review JSON file before posting it. This catches common errors like missing fields, invalid positions, or files not in the diff.

**Usage:**
```bash
./commands/validate-review.sh <pr_number> <json_file>
```

**Example:**
```bash
./commands/validate-review.sh 6 /tmp/review_comments.json
```

**Output:**
```
Validating review for PR #6
====================================

1. Validating JSON structure...
   ✓ JSON is valid

2. Checking required fields...
   ✓ commit_id present: c0120254f48e9ef351eea5619b437a17f00d9d88
   ✓ comments array present: 3 comment(s)

3. Validating each comment...
   ✓ app/components/file.ts:13 - Missing error handling...
   ✓ app/components/file.ts:28 - Add loading state...
   ✓ src/auth.ts:5 - Token validation...

4. Checking if files exist in PR diff...
   ✓ app/components/file.ts found in PR diff
   ✓ src/auth.ts found in PR diff

====================================
Validation complete!

Next step: Post the review
  gh api repos/:owner/:repo/pulls/6/reviews --input "/tmp/review_comments.json"
```

## Prerequisites

The `validate-review.sh` command requires `jq` for JSON validation:

```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

## Making Commands Executable

Before using these commands, make them executable:

```bash
chmod +x commands/calculate-position.sh
chmod +x commands/validate-review.sh
```

## Complete Workflow

1. **Get the PR diff and find positions:**
   ```bash
   ./commands/calculate-position.sh 6 app/components/file.ts
   ```

2. **Create your review JSON:**
   ```bash
   cp templates/review-template.json /tmp/my_review.json
   # Edit the file with your comments
   ```

3. **Validate before posting:**
   ```bash
   ./commands/validate-review.sh 6 /tmp/my_review.json
   ```

4. **Post the review:**
   ```bash
   gh api repos/:owner/:repo/pulls/6/reviews \
     -X POST \
     -H "Accept: application/vnd.github+json" \
     -H "X-GitHub-Api-Version: 2022-11-28" \
     --input /tmp/my_review.json
   ```
