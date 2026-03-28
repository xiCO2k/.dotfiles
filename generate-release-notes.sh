#!/bin/bash

# Generate Release Notes Script
# This script generates release notes from commit diff between production and staging

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Check if ANTHROPIC_API_KEY is set
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo -e "${RED}Error: ANTHROPIC_API_KEY environment variable is not set${NC}"
    echo "Please set it with: export ANTHROPIC_API_KEY='your-api-key'"
    exit 1
fi

echo -e "${BLUE}Fetching commit diff between production and staging...${NC}"

# Get the diff between production and staging
DIFF=$(git log production..staging --oneline --no-merges 2>/dev/null || echo "")

if [ -z "$DIFF" ]; then
    echo -e "${YELLOW}No commits found between production and staging${NC}"
    echo -e "${YELLOW}Make sure both branches exist and staging is ahead of production${NC}"
    exit 1
fi

echo -e "${GREEN}Found $(echo "$DIFF" | wc -l) commits${NC}"
echo

# Get detailed commit messages with PR numbers
DETAILED_DIFF=$(git log production..staging --pretty=format:"%h %s" --no-merges)

# Create the prompt for Claude
PROMPT="You are helping generate release notes for Laravel Cloud. Based on the following git commit diff between production and staging branches, create a PR description following the format and rules provided.

RULES FROM RELEASE.md:
- Group changes into appropriate categories
- Include PR numbers when available (format: 'in #XXXX' or 'in https://github.com/laravel/cloud/pull/XXXX')
- Use clear, concise descriptions
- Separate user-facing features from internal changes
- Use [Internal] section for technical changes that don't affect end users
- Use [Developers Only] section for API changes or developer-specific features

EXAMPLE OF A GOOD PR DESCRIPTION:
- Add new region \`us-east-1\` in https://github.com/laravel/cloud/pull/2377

[Internal]
- Add HSTS to the Strict-Transport-Security label in https://github.com/laravel/cloud/pull/2371
- Allow to delete a database schema for RDS in https://github.com/laravel/cloud/pull/2369
- Fix errors not showing in delete org modal in https://github.com/laravel/cloud/pull/2370
- Adds a slack rate limited exception for better error tracking in https://github.com/laravel/cloud/pull/2372
- Create Application reload only the providers in https://github.com/laravel/cloud/pull/2373
- Allow create database schemas with - (hyphen) in https://github.com/laravel/cloud/pull/2375

[Developers Only]
- Allow fake services to be toggled on/off on local env in https://github.com/laravel/cloud/pull/2340
- Remove not needed / redundant docblocks in https://github.com/laravel/cloud/pull/2359

COMMIT DIFF TO ANALYZE:
$DETAILED_DIFF

Please generate release notes following the format above. Group the commits logically, fix any typos, and make the descriptions clear and professional. If a commit message mentions a PR number (like #1234 or PR #1234), include it in the format shown in the example."

# Make API call to Claude
echo -e "${BLUE}Generating release notes with Claude...${NC}"

RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d "{
    \"model\": \"claude-3-5-sonnet-20241022\",
    \"max_tokens\": 2000,
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": $(echo "$PROMPT" | jq -Rs .)
      }
    ]
  }" | jq -r '.content[0].text')

if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]; then
    echo -e "${RED}Error: Failed to generate release notes${NC}"
    echo -e "${YELLOW}Falling back to simple commit list:${NC}"
    echo "$DETAILED_DIFF"
    exit 1
fi

# Output the release notes
echo -e "${GREEN}Release notes generated successfully:${NC}"
echo
echo "═══════════════════════════════════════════════════════"
echo "$RESPONSE"
echo "═══════════════════════════════════════════════════════"

# Optionally save to file
read -p "Save release notes to file? (y/n): " save_to_file
if [[ "$save_to_file" =~ ^[Yy]$ ]]; then
    FILENAME="release-notes-$(date +%Y%m%d-%H%M%S).md"
    echo "$RESPONSE" > "$FILENAME"
    echo -e "${GREEN}Release notes saved to: $FILENAME${NC}"
fi

# Optionally copy to clipboard
if command -v pbcopy &> /dev/null; then
    read -p "Copy release notes to clipboard? (y/n): " copy_to_clipboard
    if [[ "$copy_to_clipboard" =~ ^[Yy]$ ]]; then
        echo "$RESPONSE" | pbcopy
        echo -e "${GREEN}Release notes copied to clipboard${NC}"
    fi
fi