# Spotify Playlist Automation

AI-powered playlist generator using Claude CLI and n8n.

## Architecture

```
Webhook → SSH (Claude CLI) → Parse JSON → Create Playlist → Search Tracks → Add Tracks → Respond
```

**Components:**
- **n8n (LXC 109):** Workflow orchestration
- **Claude Agent (LXC 130):** Runs Claude CLI for AI recommendations
- **Spotify API:** Native n8n integration for playlist management

## Usage

```bash
curl -X POST https://n8n.harmeetrai.com/webhook/spotify-playlist \
  -H "Content-Type: application/json" \
  -d '{"prompt": "chill sunday morning vibes", "playlistName": "Sunday Morning"}'
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `prompt` | Yes | Description of the playlist mood/genre |
| `playlistName` | No | Name for the playlist (default: "Claude Playlist") |

### Response

```json
{
  "success": true,
  "playlistId": "7B8xhc4oGQDbuelGspPOHW",
  "playlistUrl": "https://open.spotify.com/playlist/7B8xhc4oGQDbuelGspPOHW"
}
```

## Setup

### 1. Claude Agent LXC (130)

```bash
# Create user
useradd -m -s /bin/bash claude

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Claude CLI (as claude user)
su - claude
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
npm install -g @anthropic-ai/claude-code

# Authenticate Claude CLI
claude login
```

### 2. SSH Access from n8n

```bash
# On n8n LXC (109)
ssh-keygen -t ed25519 -f ~/.ssh/claude_agent -N ""

# Copy to Claude Agent
ssh-copy-id -i ~/.ssh/claude_agent.pub claude@192.168.1.126
```

### 3. n8n Configuration

1. **SSH Credential:** Create with private key from `~/.ssh/claude_agent`
2. **Spotify OAuth2:** Connect via n8n credentials UI
3. **Environment Variables:**
   ```
   WEBHOOK_URL=https://n8n.harmeetrai.com/
   N8N_EDITOR_BASE_URL=https://n8n.harmeetrai.com/
   ```

### 4. Workflow

The workflow `Claude Spotify Playlist Generator` (ID: `bdnJqUV7syJNGLir`) handles:
1. Receiving webhook request
2. SSH to Claude Agent, run Claude CLI with prompt
3. Parse JSON response (10 song recommendations)
4. Create Spotify playlist
5. Search and add each track
6. Return playlist URL

## Troubleshooting

### Claude command not found
Use full path: `/home/claude/.npm-global/bin/claude`

### Trust prompt blocking execution
Add `--dangerously-skip-permissions` flag

### SSH credential issues
Ensure authentication type is set to "Private Key" in n8n

### Spotify search fails
Query must be under 250 characters - workflow searches each song individually

## Example Prompts

- "chill sunday morning vibes"
- "upbeat indie rock for running"
- "relaxing jazz for studying"
- "90s hip hop classics"
- "melancholic acoustic songs for rainy days"
- "energetic EDM for working out"
