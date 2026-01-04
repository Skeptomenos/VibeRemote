# Gateway - VibeRemote

## OVERVIEW

FastAPI proxy that manages OpenCode systemd services and proxies HTTP/SSE to the correct port.

## STRUCTURE

```
gateway/
├── main.py                 # FastAPI app (all endpoints)
├── test_all_endpoints.py   # Comprehensive API tests
├── verify_gateway.py       # Infrastructure tests
├── test_chat_flow.py       # SSE streaming tests
└── requirements.txt        # httpx, fastapi, uvicorn
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| SSE proxy | `main.py:346` | `stream_sse()` function |
| Port discovery | `main.py:139` | `find_port_from_logs()` |
| Auth | `main.py:54` | Bearer token validation |
| Start project | `main.py:238` | Starts systemd service |

## CONVENTIONS

- All endpoints require `Authorization: Bearer {key}` except `/health`
- Port discovery via journalctl (last match = current port)
- SSE proxy uses `httpx.AsyncClient.stream()`

## ANTI-PATTERNS

- **NEVER** cache port indefinitely (OpenCode restarts on random port)
- **NEVER** use first regex match for port (use LAST match)
- **NEVER** close httpx client while SSE stream is active

## COMMANDS

```bash
# Local dev
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python main.py

# Run tests
python test_all_endpoints.py
```

## NOTES

- Runs on port 4000, proxied via Cloudflare tunnel
- OpenCode binds to 127.0.0.1 only (security)
- Systemd service: `opencode@{ProjectName}.service`
