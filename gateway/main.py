"""
VibeRemote Gateway - FastAPI service for managing OpenCode instances.

This gateway:
1. Authenticates requests via Bearer token
2. Discovers projects in the user's home directory
3. Starts/stops OpenCode instances via systemd user services
4. Proxies API requests to the correct OpenCode instance
"""

import asyncio
import os
import re
import subprocess
from pathlib import Path
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException, Request, Response, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

# Configuration
AUTH_SECRET = os.environ.get("VIBE_AUTH_SECRET", "change-me-in-production")
HOME_DIR = Path(os.environ.get("HOME_DIR", "/home/linux"))
PORT_RANGE_START = int(os.environ.get("PORT_RANGE_START", "4096"))
PORT_RANGE_END = int(os.environ.get("PORT_RANGE_END", "4196"))

# Track running instances: project_name -> port
running_instances: dict[str, int] = {}

app = FastAPI(
    title="VibeRemote Gateway",
    description="Gateway for managing OpenCode instances",
    version="1.0.0",
)

# CORS for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =============================================================================
# Authentication
# =============================================================================


async def verify_auth(request: Request) -> None:
    """Verify Bearer token authentication."""
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=401, detail="Missing or invalid Authorization header"
        )

    token = auth_header[7:]  # Remove "Bearer " prefix
    if token != AUTH_SECRET:
        raise HTTPException(status_code=401, detail="Invalid API key")


# =============================================================================
# Models
# =============================================================================


class Project(BaseModel):
    name: str
    path: str
    has_git: bool
    has_package_json: bool
    is_running: bool
    port: Optional[int] = None


class StartResponse(BaseModel):
    name: str
    port: int
    status: str


class StopResponse(BaseModel):
    name: str
    status: str


# =============================================================================
# Helper Functions
# =============================================================================


def sanitize_project_name(name: str) -> str:
    """Sanitize project name for use in systemd service names."""
    # Only allow alphanumeric, dash, underscore
    return re.sub(r"[^a-zA-Z0-9_-]", "_", name)


def get_service_name(project_name: str) -> str:
    """Get systemd service name for a project."""
    return f"opencode@{sanitize_project_name(project_name)}"


async def run_systemctl(action: str, service: str) -> tuple[int, str, str]:
    """Run a systemctl --user command."""
    proc = await asyncio.create_subprocess_exec(
        "systemctl",
        "--user",
        action,
        service,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    return proc.returncode, stdout.decode(), stderr.decode()


async def get_service_status(project_name: str) -> tuple[bool, Optional[int]]:
    """Check if a service is running and get its port."""
    service = get_service_name(project_name)
    returncode, stdout, _ = await run_systemctl("is-active", service)

    is_running = returncode == 0
    port = running_instances.get(project_name)

    # If running but we don't have the port, try to find it from logs
    if is_running and port is None:
        port = await find_port_from_logs(project_name)
        if port:
            running_instances[project_name] = port

    return is_running, port


async def find_port_from_logs(project_name: str) -> Optional[int]:
    """Find the port from journalctl logs."""
    service = get_service_name(project_name)
    try:
        proc = await asyncio.create_subprocess_exec(
            "journalctl",
            "--user",
            "-u",
            service,
            "-n",
            "50",
            "--no-pager",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()
        output = stdout.decode()

        # Look for "listening on http://127.0.0.1:XXXXX"
        # Use findall and take the LAST match to ensure we get the most recent port
        # journalctl outputs logs chronologically (oldest first), so the last match is the newest
        matches = re.findall(r"listening on http://[^:]+:(\d+)", output)
        if matches:
            return int(matches[-1])
    except Exception:
        pass
    return None


async def wait_for_port(project_name: str, timeout: float = 30.0) -> Optional[int]:
    """Wait for the service to start and report its port."""
    start_time = asyncio.get_event_loop().time()

    while asyncio.get_event_loop().time() - start_time < timeout:
        port = await find_port_from_logs(project_name)
        if port:
            # Verify the port is actually responding
            try:
                async with httpx.AsyncClient() as client:
                    resp = await client.get(
                        f"http://127.0.0.1:{port}/global/health", timeout=2.0
                    )
                    if resp.status_code == 200:
                        return port
            except Exception:
                pass
        await asyncio.sleep(0.5)

    return None


# =============================================================================
# Endpoints
# =============================================================================


@app.get("/health")
async def health_check():
    """Health check endpoint (no auth required)."""
    return {"status": "ok", "service": "viberemote-gateway"}


@app.get("/projects", dependencies=[Depends(verify_auth)])
async def list_projects() -> list[Project]:
    """List all projects in the home directory."""
    projects = []

    try:
        for entry in HOME_DIR.iterdir():
            if not entry.is_dir():
                continue
            if entry.name.startswith("."):
                continue

            # Check for project indicators
            has_git = (entry / ".git").exists()
            has_package_json = (entry / "package.json").exists()

            # Get running status
            is_running, port = await get_service_status(entry.name)

            projects.append(
                Project(
                    name=entry.name,
                    path=str(entry),
                    has_git=has_git,
                    has_package_json=has_package_json,
                    is_running=is_running,
                    port=port,
                )
            )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list projects: {e}")

    # Sort by name
    projects.sort(key=lambda p: p.name.lower())
    return projects


@app.post("/projects/{project_name}/start", dependencies=[Depends(verify_auth)])
async def start_project(project_name: str) -> StartResponse:
    """Start an OpenCode instance for a project."""
    # Validate project exists
    project_path = HOME_DIR / project_name
    if not project_path.exists() or not project_path.is_dir():
        raise HTTPException(
            status_code=404, detail=f"Project not found: {project_name}"
        )

    # Check if already running
    is_running, port = await get_service_status(project_name)
    if is_running and port:
        return StartResponse(name=project_name, port=port, status="already_running")

    # Start the service
    service = get_service_name(project_name)
    returncode, stdout, stderr = await run_systemctl("start", service)

    if returncode != 0:
        raise HTTPException(
            status_code=500, detail=f"Failed to start service: {stderr or stdout}"
        )

    # Wait for port
    port = await wait_for_port(project_name)
    if not port:
        raise HTTPException(
            status_code=500,
            detail="Service started but failed to get port. Check logs with: journalctl --user -u "
            + service,
        )

    running_instances[project_name] = port
    return StartResponse(name=project_name, port=port, status="started")


@app.delete("/projects/{project_name}/stop", dependencies=[Depends(verify_auth)])
async def stop_project(project_name: str) -> StopResponse:
    """Stop an OpenCode instance for a project."""
    service = get_service_name(project_name)
    returncode, stdout, stderr = await run_systemctl("stop", service)

    if returncode != 0:
        raise HTTPException(
            status_code=500, detail=f"Failed to stop service: {stderr or stdout}"
        )

    # Remove from tracking
    running_instances.pop(project_name, None)
    return StopResponse(name=project_name, status="stopped")


@app.get("/projects/{project_name}/status", dependencies=[Depends(verify_auth)])
async def project_status(project_name: str) -> Project:
    """Get status of a specific project."""
    project_path = HOME_DIR / project_name
    if not project_path.exists() or not project_path.is_dir():
        raise HTTPException(
            status_code=404, detail=f"Project not found: {project_name}"
        )

    is_running, port = await get_service_status(project_name)

    return Project(
        name=project_name,
        path=str(project_path),
        has_git=(project_path / ".git").exists(),
        has_package_json=(project_path / "package.json").exists(),
        is_running=is_running,
        port=port,
    )


@app.api_route(
    "/projects/{project_name}/api/{path:path}",
    methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    dependencies=[Depends(verify_auth)],
)
async def proxy_to_opencode(project_name: str, path: str, request: Request) -> Response:
    """Proxy requests to the OpenCode instance."""
    # Get the port for this project
    is_running, port = await get_service_status(project_name)

    if not is_running or not port:
        raise HTTPException(
            status_code=503,
            detail=f"OpenCode instance for {project_name} is not running. Start it first.",
        )

    # Build the target URL
    target_url = f"http://127.0.0.1:{port}/{path}"
    if request.url.query:
        target_url += f"?{request.url.query}"

    # Get request body if present
    body = await request.body()

    # Forward headers (except Host and Authorization which we handle)
    headers = dict(request.headers)
    headers.pop("host", None)
    headers.pop("authorization", None)

    # Check if this is an SSE request
    accept = headers.get("accept", "")
    is_sse = "text/event-stream" in accept or path == "event"

    if is_sse:

        async def stream_sse():
            async with httpx.AsyncClient() as client:
                try:
                    async with client.stream(
                        request.method,
                        target_url,
                        headers=headers,
                        content=body,
                        timeout=None,
                    ) as response:
                        async for chunk in response.aiter_bytes():
                            yield chunk
                except Exception as e:
                    print(f"SSE Stream Error: {e}")

        return StreamingResponse(
            stream_sse(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
            },
        )
    else:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.request(
                    request.method,
                    target_url,
                    headers=headers,
                    content=body,
                    timeout=60.0,
                )

                return Response(
                    content=response.content,
                    status_code=response.status_code,
                    headers=dict(response.headers),
                )
        except httpx.ConnectError:
            raise HTTPException(
                status_code=503,
                detail=f"Cannot connect to OpenCode instance on port {port}",
            )
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Proxy error: {str(e)}")


# =============================================================================
# Startup
# =============================================================================


@app.on_event("startup")
async def startup_event():
    """Discover already-running instances on startup."""
    print(f"VibeRemote Gateway starting...")
    print(f"Home directory: {HOME_DIR}")
    print(
        f"Auth secret configured: {'Yes' if AUTH_SECRET != 'change-me-in-production' else 'NO - USING DEFAULT!'}"
    )

    # Scan for running instances
    try:
        for entry in HOME_DIR.iterdir():
            if not entry.is_dir() or entry.name.startswith("."):
                continue

            is_running, port = await get_service_status(entry.name)
            if is_running and port:
                running_instances[entry.name] = port
                print(f"  Found running: {entry.name} on port {port}")
    except Exception as e:
        print(f"Warning: Failed to scan for running instances: {e}")

    print(f"Gateway ready. Found {len(running_instances)} running instance(s).")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=4000)
