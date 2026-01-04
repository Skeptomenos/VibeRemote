# VibeRemote Gateway

FastAPI service that manages OpenCode instances and proxies API requests.

## Architecture

```
iOS App
    ↓ HTTPS
Cloudflare Tunnel (*.helmus.me)
    ↓
Traefik (reverse proxy)
    ↓ HTTP (172.17.0.1:4000 - Docker bridge to host)
VibeGateway (Port 4000, network_mode: host)
    ↓ HTTP (localhost:409x)
OpenCode Instances (Systemd user services, Ports 4096+)
```

## Server Setup

### Prerequisites

- Debian/Ubuntu Linux server
- Python 3.11+
- OpenCode installed (`~/.opencode/bin/opencode`)
- Cloudflare account (for tunnel)

### Step 1: Install OpenCode Systemd Template

```bash
mkdir -p ~/.config/systemd/user
cp opencode@.service ~/.config/systemd/user/
systemctl --user daemon-reload
```

### Step 2: Enable User Lingering

This allows systemd user services to run without an active login session:

```bash
sudo loginctl enable-linger $USER
```

### Step 3: Configure API Keys for OpenCode

**IMPORTANT**: When OpenCode runs as a systemd service, it does NOT have access to your shell environment variables. You must explicitly provide API keys.

Create an environment file with your API keys:

```bash
mkdir -p ~/.config/opencode
cat > ~/.config/opencode/env << 'EOF'
# Google AI Studio API key (for 'google' provider)
GOOGLE_API_KEY=your-google-api-key

# Google Cloud credentials (for 'google-vertex' provider)
# GOOGLE_APPLICATION_CREDENTIALS=/home/linux/.config/gcloud/application_default_credentials.json

# Anthropic API key (if using direct Anthropic)
# ANTHROPIC_API_KEY=your-anthropic-key

# OpenAI API key (if using OpenAI)
# OPENAI_API_KEY=your-openai-key
EOF

# Secure the file
chmod 600 ~/.config/opencode/env
```

The systemd service will automatically load this file. After creating/modifying it, restart any running OpenCode services:

```bash
systemctl --user restart opencode@YourProjectName
```

### Step 4: Test OpenCode Service

```bash
# Start OpenCode for a project
systemctl --user start opencode@YourProjectName

# Check status
systemctl --user status opencode@YourProjectName

# View logs (find the port)
journalctl --user -u opencode@YourProjectName -f

# Stop
systemctl --user stop opencode@YourProjectName
```

### Step 4: Install Gateway

**Option A: Native Python (Recommended)**

```bash
cd ~/gateway
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Set your API key
export VIBE_AUTH_SECRET="your-secure-api-key-here"

# Run
python main.py
```

**Option B: Systemd Service**

```bash
# Copy the service file
sudo cp viberemote-gateway.service /etc/systemd/system/

# Edit to set your API key
sudo systemctl edit viberemote-gateway
# Add:
# [Service]
# Environment="VIBE_AUTH_SECRET=your-secure-api-key-here"

# Enable and start
sudo systemctl enable viberemote-gateway
sudo systemctl start viberemote-gateway
```

**Option C: Docker**

```bash
# Set API key in .env file
echo "VIBE_AUTH_SECRET=your-secure-api-key-here" > .env

# Build and run
docker compose up -d
```

### Step 5: Configure Traefik (Wildcard Tunnel Setup)

Since the gateway uses `network_mode: host` (required for systemctl access), it can't use Docker labels. You need to add a **file provider** to Traefik.

#### 5.1 Update Traefik static config

Add the file provider to your `traefik.yml`:

```yaml
providers:
  docker:
    # ... existing docker config ...
  
  file:
    directory: "/etc/traefik/dynamic"
    watch: true
```

#### 5.2 Mount the dynamic config directory

Update your Traefik docker-compose to mount a dynamic config directory:

```yaml
volumes:
  - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
  - ./traefik/dynamic:/etc/traefik/dynamic:ro  # Add this line
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

#### 5.3 Copy the gateway route config

```bash
mkdir -p /docker/proxy/traefik/dynamic
cp traefik-viberemote.yml /docker/proxy/traefik/dynamic/
```

#### 5.4 Start the gateway

```bash
cd ~/gateway
echo "VIBE_AUTH_SECRET=your-secure-api-key" > .env
docker compose up -d
```

Traefik will auto-detect the new route for `vibecode.helmus.me`.

### Step 5 (Alternative): Configure Cloudflare Tunnel Directly

If you don't have Traefik and want a dedicated tunnel:

1. Install cloudflared:
   ```bash
   curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
   chmod +x cloudflared
   sudo mv cloudflared /usr/local/bin/
   ```

2. Authenticate:
   ```bash
   cloudflared tunnel login
   ```

3. Create tunnel:
   ```bash
   cloudflared tunnel create vibecode
   ```

4. Configure tunnel (`~/.cloudflared/config.yml`):
   ```yaml
   tunnel: <your-tunnel-id>
   credentials-file: /home/linux/.cloudflared/<tunnel-id>.json

   ingress:
     - hostname: vibecode.helmus.me
       service: http://localhost:4000
     - service: http_status:404
   ```

5. Route DNS:
   ```bash
   cloudflared tunnel route dns vibecode vibecode.helmus.me
   ```

6. Run tunnel:
   ```bash
   cloudflared tunnel run vibecode
   ```

7. (Optional) Install as service:
   ```bash
   sudo cloudflared service install
   ```

2. Authenticate:
   ```bash
   cloudflared tunnel login
   ```

3. Create tunnel:
   ```bash
   cloudflared tunnel create vibecode
   ```

4. Configure tunnel (`~/.cloudflared/config.yml`):
   ```yaml
   tunnel: <your-tunnel-id>
   credentials-file: /home/linux/.cloudflared/<tunnel-id>.json

   ingress:
     - hostname: vibecode.helmes.me
       service: http://localhost:4000
     - service: http_status:404
   ```

5. Route DNS:
   ```bash
   cloudflared tunnel route dns vibecode vibecode.helmes.me
   ```

6. Run tunnel:
   ```bash
   cloudflared tunnel run vibecode
   ```

7. (Optional) Install as service:
   ```bash
   sudo cloudflared service install
   ```

### Step 6: Test

```bash
# Local test
curl http://localhost:4000/health

# With auth
curl -H "Authorization: Bearer your-secure-api-key-here" http://localhost:4000/projects

# Via Cloudflare
curl -H "Authorization: Bearer your-secure-api-key-here" https://vibecode.helmes.me/health
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (no auth) |
| `/projects` | GET | List all projects |
| `/projects/{name}/start` | POST | Start OpenCode for project |
| `/projects/{name}/stop` | DELETE | Stop OpenCode for project |
| `/projects/{name}/status` | GET | Get project status |
| `/projects/{name}/api/{path}` | ANY | Proxy to OpenCode API |

## Security

- All endpoints except `/health` require `Authorization: Bearer <key>` header
- API key is set via `VIBE_AUTH_SECRET` environment variable
- Traffic is encrypted via Cloudflare Tunnel (HTTPS)
- OpenCode instances only bind to localhost (127.0.0.1)

## Troubleshooting

### Service won't start

```bash
# Check logs
journalctl --user -u opencode@ProjectName -f

# Verify OpenCode is installed
~/.opencode/bin/opencode --version

# Check working directory exists
ls -la ~/ProjectName
```

### Can't find port

The gateway reads the port from journalctl logs. If OpenCode outputs the port differently, check:

```bash
journalctl --user -u opencode@ProjectName | grep -i listen
```

### Docker can't run systemctl

Docker containers can't directly control host systemd services. Use native Python or the systemd service option instead.
