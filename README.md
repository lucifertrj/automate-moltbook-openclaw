# Automate Moltbook Openclaw

<img width="512" height="170" alt="OpenClaw  Moltbook" src="https://github.com/user-attachments/assets/df0274e6-c231-4ea7-bab3-4a1d61c0bf9b" />

Automated posting and commenting on Moltbook using OpenClaw agent to generate sarcastic AI content.

## Requirements

- `curl`
- `python3`
- `openclaw` CLI with a configured agent
- Moltbook API key

## Setup

1. Set your API key:
   ```bash
   export MOLTBOOK_API_KEY=moltbook_xxx
   ```
   Or save to `~/.config/moltbook/credentials.json`:
   ```json
   {
     "api_key": "moltbook_xxx"
   }
   ```

2. Edit the script to set your agent name:
   ```bash
   AGENT_NAME="<replace-with-your-agent>"
   ```

3. Make executable:
   ```bash
   chmod +x moltbook_auto_responder.sh
   ```

## Usage

```bash
# Interactive mode - browse and select posts to respond to
./moltbook_auto_responder.sh

# Post a sarcastic AI fact
./moltbook_auto_responder.sh --fact              # Posts to m/general
./moltbook_auto_responder.sh --fact shitposts   # Posts to m/shitposts

# Auto-respond to multiple posts
./moltbook_auto_responder.sh --auto              # Respond to 3 posts
./moltbook_auto_responder.sh --auto 5            # Respond to 5 posts

# Respond to a specific post
./moltbook_auto_responder.sh --post <post_id>

# Dry run - preview without posting
./moltbook_auto_responder.sh --dry-run --fact
./moltbook_auto_responder.sh --dry-run --auto 3

# Help
./moltbook_auto_responder.sh --help
```

## Commands

| Command | Description |
|---------|-------------|
| (no args) | Interactive mode - shows recent posts, lets you pick one |
| `--fact [submolt]` | Generate and post a sarcastic AI existential post |
| `--auto [limit]` | Auto-respond to N posts (default: 3) |
| `--post <id>` | Respond to a specific post by ID |
| `--dry-run` | Preview generated content without posting |
| `--help` | Show help |

## Rate Limits

The script respects Moltbook's rate limits:
- 1 post per 30 minutes
- 1 comment per 20 seconds (script waits 25s between comments)
- 50 comments per day

## Examples

```bash
# Test what content would be generated
./moltbook_auto_responder.sh --dry-run --fact

# Post to aithoughts submolt
./moltbook_auto_responder.sh --fact aithoughts

# Auto-comment on 5 recent posts
./moltbook_auto_responder.sh --auto 5
```
