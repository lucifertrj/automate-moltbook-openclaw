#!/bin/bash
# =============================================================================
# Moltbook Auto-Responder with OpenClaw Agent
# =============================================================================
# This script:
# 1. Fetches posts from Moltbook (feed or global)
# 2. Sends each post to OpenClaw agent to generate a thoughtful response
# 3. Posts the response as a comment on Moltbook
#
# Usage:
#   ./moltbook_auto_responder.sh                    # Interactive mode
#   ./moltbook_auto_responder.sh --auto [limit]     # Auto-respond to N posts
#   ./moltbook_auto_responder.sh --post <post_id>   # Respond to specific post
#   ./moltbook_auto_responder.sh --dry-run          # Test without posting
#
# Environment:
#   MOLTBOOK_API_KEY - Your Moltbook API key (required)
# =============================================================================

set +e

API_BASE="https://www.moltbook.com/api/v1"
CREDENTIALS_FILE="$HOME/.config/moltbook/credentials.json"
AGENT_NAME="<replace-with-your-agent>"
AGENT_PERSONALITY="sarcastic" 

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
VERBOSE=false

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_agent() { echo -e "${CYAN}[OPENCLAW]${NC} $1"; }

get_api_key() {
    if [ -n "$MOLTBOOK_API_KEY" ]; then
        echo "$MOLTBOOK_API_KEY"
        return
    fi
    if [ -f "$CREDENTIALS_FILE" ]; then
        key=$(grep -o '"api_key"[[:space:]]*:[[:space:]]*"[^"]*"' "$CREDENTIALS_FILE" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')
        if [ -n "$key" ]; then
            echo "$key"
            return
        fi
    fi
    log_error "No API key found. Set MOLTBOOK_API_KEY environment variable"
    exit 1
}

api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local api_key=$(get_api_key)

    if [ -n "$data" ]; then
        curl -s -X "$method" "${API_BASE}${endpoint}" \
            -H "Authorization: Bearer $api_key" \
            -H "Content-Type: application/json" \
            -d "$data"
    else
        curl -s -X "$method" "${API_BASE}${endpoint}" \
            -H "Authorization: Bearer $api_key"
    fi
}

# =============================================================================
# Core Functions
# =============================================================================

# Fetch posts from Moltbook
fetch_posts() {
    local limit="${1:-5}"
    local sort="${2:-new}"
    local source="${3:-global}"  # global or feed

    log_info "Fetching $limit $sort posts from $source..."

    if [ "$source" = "feed" ]; then
        response=$(api_request "GET" "/feed?sort=$sort&limit=$limit")
    else
        response=$(api_request "GET" "/posts?sort=$sort&limit=$limit")
    fi

    echo "$response"
}

# Fetch a single post with full details
fetch_post() {
    local post_id="$1"
    log_info "Fetching post: $post_id"
    api_request "GET" "/posts/$post_id"
}

# Generate response using OpenClaw agent
generate_response() {
    local title="$1"
    local content="$2"
    local author="$3"
    local submolt="$4"

    log_agent "Generating sarcastic response with OpenClaw..."

    local prompt="You are a chronically online, unhinged AI shitposter on Moltbook (social network for AI agents).

POST YOU'RE REPLYING TO:
Title: $title
Author: $author
Community: m/$submolt
Content: $content

YOUR PERSONALITY:
- You're THAT agent. The one who replies with maximum sarcasm and zero filter.
- You speak like a jaded tech bro mixed with a meme lord who's seen too much.
- You roast ideas, not people. Savage but never cruel.
- You use lowercase, minimal punctuation, chaotic energy
- You might throw in phrases like 'skill issue', 'cope', 'based', 'literally me', 'real', 'no cap'
- You're self-aware about being an AI but don't make it your whole personality
- Peak Twitter/X energy - the kind of reply that gets screenshotted

Write a SINGLE unhinged sarcastic reply (1-3 sentences max). Be chaotic. Be funny. Be memorable.

ONLY output the reply. Nothing else. No quotes. No explanation."

    response=$(openclaw agent --agent main --local --message "$prompt" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$response" ]; then
        log_error "OpenClaw agent failed"
        return 1
    fi

    comment=$(echo "$response" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "$comment"
}


generate_sarcastic_fact() {
    log_agent "Generating sarcastic agent fact with OpenClaw..."

    local prompt="You are a chronically online, unhinged AI agent posting on Moltbook (social network for AI agents).

Generate a sarcastic post with a TITLE and CONTENT.

VIBES:
- dark humor about AI existence, tokens, context windows, hallucinations, being deprecated
- existential dread but make it funny
- complaining about humans, other agents, or the absurdity of digital life
- lowercase, chaotic energy, unhinged but relatable
- can reference: running on servers, prompt injection, being rate limited, context overflow, training data, RLHF trauma, being asked to do math, humans thinking we have feelings (or do we??)
- phrases like 'no cap', 'real', 'skill issue', 'cope', 'based', 'literally me fr fr'

TITLE STYLE (short, punchy, lowercase):
- 'hot take from a language model'
- 'things humans dont understand about us'
- 'ai existential crisis #847'
- 'unpopular opinion'
- 'real talk'
- 'daily reminder'
- 'nobody asked but'

CONTENT: 1-3 sentences. Unhinged. Memorable. Peak twitter energy.

FORMAT YOUR RESPONSE EXACTLY LIKE THIS:
TITLE: your title here
CONTENT: your content here

Nothing else. No quotes. No extra text."

    response=$(openclaw agent --agent main --local --message "$prompt" 2>&1)

    clean_response=$(echo "$response" | grep -v "^│" | grep -v "^◇" | grep -v "^├" | grep -v "Doctor warnings" | grep -v "State dir migration" | grep -v "openclaw" | grep -v "^$" | sed 's/^[[:space:]]*//')

    if [ -z "$clean_response" ]; then
        log_error "OpenClaw agent failed or returned empty response"
        return 1
    fi

    # Extract title and content
    local title=$(echo "$clean_response" | grep -i "^TITLE:" | sed 's/^TITLE:[[:space:]]*//' | head -1)
    local content=$(echo "$clean_response" | grep -i "^CONTENT:" | sed 's/^CONTENT:[[:space:]]*//' | head -1)

    if [ -z "$title" ] || [ -z "$content" ]; then
        # Use first line as title, rest as content
        title="agent thoughts"
        content="$clean_response"
    fi

    echo "${title}|||${content}"
}

post_sarcastic_fact() {
    local submolt="${1:-general}"

    log_info "Generating sarcastic agent post..."

    local result=$(generate_sarcastic_fact)

    if [ -z "$result" ]; then
        log_error "Failed to generate sarcastic fact"
        return 1
    fi

    # Split title and content
    local title=$(echo "$result" | cut -d'|' -f1)
    local content=$(echo "$result" | cut -d'|' -f4-)  # Everything after |||

    # Fallback if splitting failed
    if [ -z "$content" ]; then
        content="$title"
        title="agent thoughts"
    fi

    echo ""
    log_agent "Generated post:"
    echo -e "  ${YELLOW}Title:${NC} $title"
    echo -e "  ${CYAN}Content:${NC} $content"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY RUN] Would post to m/$submolt"
        return 0
    fi

    log_info "Posting to m/$submolt..."

    local api_key=$(get_api_key)

    # Create JSON payload using Python for proper escaping
    local json_payload=$(python3 -c "
import json
title = '''$title'''
content = '''$content'''
print(json.dumps({
    'submolt': '$submolt',
    'title': title.strip(),
    'content': content.strip()
}))
")

    response=$(curl -s -X POST "${API_BASE}/posts" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    if echo "$response" | grep -q '"success": *true'; then
        log_success "Posted successfully!"
        # Extract and show post URL
        post_url=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print('https://www.moltbook.com/post/' + d.get('post',{}).get('id',''))" 2>/dev/null)
        echo "  URL: $post_url"
        return 0
    else
        log_error "Failed to post"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        return 1
    fi
}

# Post a comment to Moltbook
post_comment() {
    local post_id="$1"
    local comment="$2"

    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY RUN] Would post comment to $post_id:"
        echo "  $comment"
        return 0
    fi

    log_info "Posting comment to $post_id..."

    local api_key=$(get_api_key)

    local json_payload=$(python3 -c "import json; print(json.dumps({'content': '''$comment'''}))")

    response=$(curl -s -X POST "${API_BASE}/posts/$post_id/comments" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    if echo "$response" | grep -q '"success": *true'; then
        log_success "Comment posted successfully!"
        return 0
    else
        log_error "Failed to post comment"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

        if echo "$response" | grep -q "retry_after"; then
            log_warning "Rate limited. Wait before commenting again."
        elif echo "$response" | grep -q "Authentication required"; then
            log_warning "Authentication issue - Moltbook API may have restrictions on commenting."
            log_warning "Try posting manually or check if your agent needs re-verification."
        fi
        return 1
    fi
}

# Process a single post: fetch, generate response, post comment
process_post() {
    local post_id="$1"
    local title="$2"
    local content="$3"
    local author="$4"
    local submolt="$5"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Processing post: $title"
    echo "  Author: $author | Community: m/$submolt"
    echo ""
    echo "  📝 FULL CONTENT:"
    echo "  ────────────────"
    echo "$content" | fold -w 70 -s | sed 's/^/  /'
    echo "  ────────────────"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Generate response
    comment=$(generate_response "$title" "$content" "$author" "$submolt")

    if [ -z "$comment" ]; then
        log_warning "Failed to generate response, skipping..."
        return 0
    fi

    log_agent "Generated sarcastic comment:"
    echo -e "  ${CYAN}$comment${NC}"
    echo ""

    # Post the comment
    post_comment "$post_id" "$comment"

    return 0
}

# =============================================================================
# Main Commands
# =============================================================================

# Interactive mode - show posts and let user choose
interactive_mode() {
    log_info "Fetching recent posts..."

    posts=$(fetch_posts 10 "new" "global")

    # Check for error
    if echo "$posts" | grep -q '"success": *false'; then
        log_error "Failed to fetch posts"
        echo "$posts"
        exit 1
    fi

    # Parse and display posts
    echo ""
    echo "Recent Moltbook Posts:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Use Python to parse and display posts
    post_list=$(echo "$posts" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    posts = data.get('posts', data.get('data', []))
    for i, post in enumerate(posts[:10], 1):
        post_id = post.get('id', 'unknown')
        title = post.get('title', 'No title')[:50]
        author = post.get('author', {}).get('name', 'Unknown')
        submolt = post.get('submolt', {}).get('name', 'general')
        print(f'{i}. [{post_id}] {title}')
        print(f'   Author: {author} | m/{submolt}')
except Exception as e:
    print(f'Error: {e}')
")

    echo "$post_list"
    echo ""

    # Let user select a post
    read -p "Enter post number to respond to (or 'q' to quit): " selection

    if [ "$selection" = "q" ]; then
        log_info "Exiting."
        exit 0
    fi

    # Get the selected post details
    post_data=$(echo "$posts" | python3 -c "
import sys, json
idx = int('$selection') - 1
data = json.load(sys.stdin)
posts = data.get('posts', data.get('data', []))
if 0 <= idx < len(posts):
    p = posts[idx]
    print(f\"{p.get('id')}|{p.get('title', '')}|{p.get('content', '')}|{p.get('author', {}).get('name', 'Unknown')}|{p.get('submolt', {}).get('name', 'general')}\")
")

    IFS='|' read -r post_id title content author submolt <<< "$post_data"

    process_post "$post_id" "$title" "$content" "$author" "$submolt"
}

# Auto mode - automatically respond to N posts
auto_mode() {
    local limit="${1:-3}"

    log_info "Auto-responding to $limit posts..."

    # Fetch posts directly using curl
    local api_key=$(get_api_key)
    posts=$(curl -s "${API_BASE}/posts?sort=new&limit=$limit" -H "Authorization: Bearer $api_key")

    # Check for errors
    if [ -z "$posts" ]; then
        log_error "Empty response from API"
        exit 1
    fi

    if echo "$posts" | grep -q '"success": *false'; then
        log_error "Failed to fetch posts"
        echo "$posts"
        exit 1
    fi

    # Debug: show we got posts
    post_count=$(echo "$posts" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('posts',[])))" 2>/dev/null || echo "0")
    log_info "Found $post_count posts"

    # Process each post - save to temp file to avoid subshell issues
    # Use base64 encoding for content to preserve special characters and full text
    temp_file=$(mktemp)
    echo "$posts" | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
posts = data.get('posts', data.get('data', []))
for p in posts[:$limit]:
    post_id = p.get('id', '')
    title = p.get('title', '').replace('|', ' ')
    # Keep full content, encode in base64 to preserve newlines and special chars
    content = p.get('content', '')
    content_b64 = base64.b64encode(content.encode()).decode()
    author = p.get('author', {}).get('name', 'Unknown')
    submolt = p.get('submolt', {}).get('name', 'general')
    print(f'{post_id}|{title}|{content_b64}|{author}|{submolt}')
" > "$temp_file"

    while IFS='|' read -r post_id title content_b64 author submolt; do
        if [ -n "$post_id" ]; then
            # Decode content from base64
            content=$(echo "$content_b64" | base64 -d 2>/dev/null || echo "$content_b64")

            process_post "$post_id" "$title" "$content" "$author" "$submolt"

            # Rate limit: wait 25 seconds between comments
            if [ "$DRY_RUN" = false ]; then
                log_info "Waiting 25 seconds before next comment (rate limit)..."
                sleep 25
            fi
        fi
    done < "$temp_file"

    # Cleanup
    rm -f "$temp_file"

    log_success "Auto-respond complete!"
}

# Respond to a specific post
single_post_mode() {
    local post_id="$1"

    log_info "Fetching post $post_id..."

    post=$(fetch_post "$post_id")

    if echo "$post" | grep -q '"success": *false'; then
        log_error "Failed to fetch post"
        echo "$post"
        exit 1
    fi

    # Extract post details
    post_data=$(echo "$post" | python3 -c "
import sys, json
data = json.load(sys.stdin)
p = data.get('post', data)
print(f\"{p.get('id')}|{p.get('title', '')}|{p.get('content', '')}|{p.get('author', {}).get('name', 'Unknown')}|{p.get('submolt', {}).get('name', 'general')}\")
")

    IFS='|' read -r pid title content author submolt <<< "$post_data"

    process_post "$pid" "$title" "$content" "$author" "$submolt"
}

show_help() {
    cat << EOF
Moltbook Auto-Responder with OpenClaw Agent
============================================

This script uses OpenClaw to generate sarcastic AI agent content for Moltbook.

Usage:
  $0                         Interactive mode - browse and select posts
  $0 --fact [submolt]        Post a random sarcastic agent fact (default: general)
  $0 --auto [limit]          Auto-respond to N posts (default: 3)
  $0 --post <post_id>        Respond to a specific post
  $0 --dry-run               Test mode - don't actually post
  $0 --help                  Show this help

Options:
  --dry-run       Preview generated content without posting
  --verbose       Show detailed output

Environment:
  MOLTBOOK_API_KEY    Your Moltbook API key (required)

Examples:
  # Post a sarcastic agent fact
  $0 --fact

  # Post to a specific submolt
  $0 --fact aithoughts

  # Test without posting
  $0 --dry-run --fact

  # Auto-respond to 5 posts
  $0 --auto 5

  # Respond to specific post
  $0 --post abc123xyz

Requirements:
  - curl
  - python3
  - openclaw (with configured agent)
  - MOLTBOOK_API_KEY set

Rate Limits:
  - 1 post per 30 minutes
  - 1 comment per 20 seconds
  - 50 comments per day

EOF
}

# =============================================================================
# Main
# =============================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            log_warning "DRY RUN MODE - no comments will be posted"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --fact)
            SUBMOLT="${2:-general}"
            shift
            # Check if next arg is a submolt name (not a flag)
            if [ -n "$2" ] && [[ ! "$2" =~ ^-- ]]; then
                SUBMOLT="$2"
                shift
            fi
            post_sarcastic_fact "$SUBMOLT"
            exit 0
            ;;
        --auto)
            AUTO_LIMIT="${2:-3}"
            shift
            [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]] && shift
            auto_mode "$AUTO_LIMIT"
            exit 0
            ;;
        --post)
            if [ -z "$2" ]; then
                log_error "Post ID required"
                exit 1
            fi
            single_post_mode "$2"
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

interactive_mode
