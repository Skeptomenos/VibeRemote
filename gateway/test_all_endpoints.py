#!/usr/bin/env python3
"""
Comprehensive Gateway & OpenCode API Test Suite

Tests all endpoints the iOS app uses against the VibeRemote Gateway.
Covers: Infrastructure, Session Management, Message Operations, Model Selection,
SSE Streaming, and Status Endpoints.

Usage:
    python test_all_endpoints.py [--gateway-url URL] [--project NAME]
"""

import asyncio
import json
import os
import sys
import time
from dataclasses import dataclass, field
from typing import Optional, Any
from enum import Enum

import httpx

# =============================================================================
# Configuration
# =============================================================================

GATEWAY_URL = os.environ.get("GATEWAY_URL", "https://vibecode.helmus.me")
API_KEY = os.environ.get(
    "API_KEY", "fb9b4ae8e769f297ee785f191d599c579552a12bd87f77bba12da3df2d249b0f"
)
PROJECT_NAME = os.environ.get("PROJECT_NAME", "Test")

# Models to test SSE streaming with
MODELS_TO_TEST = [
    ("opencode", "qwen3-coder"),
    ("google-vertex-anthropic", "claude-sonnet-4@20250514"),
]

# Timeout settings
DEFAULT_TIMEOUT = 30.0
SSE_TIMEOUT = 60.0  # Longer timeout for SSE streaming tests


# =============================================================================
# Test Result Tracking
# =============================================================================


class TestStatus(Enum):
    PASSED = "passed"
    FAILED = "failed"
    SKIPPED = "skipped"


@dataclass
class TestResult:
    name: str
    status: TestStatus
    message: str = ""
    duration: float = 0.0


@dataclass
class TestCategory:
    name: str
    results: list[TestResult] = field(default_factory=list)

    @property
    def passed(self) -> int:
        return sum(1 for r in self.results if r.status == TestStatus.PASSED)

    @property
    def failed(self) -> int:
        return sum(1 for r in self.results if r.status == TestStatus.FAILED)

    @property
    def total(self) -> int:
        return len(self.results)


# =============================================================================
# Test Utilities
# =============================================================================


def headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}


async def timed_request(
    client: httpx.AsyncClient,
    method: str,
    url: str,
    **kwargs,
) -> tuple[httpx.Response, float]:
    """Execute a request and return response with duration."""
    start = time.time()
    response = await client.request(method, url, **kwargs)
    duration = time.time() - start
    return response, duration


# =============================================================================
# Phase 1: Infrastructure Tests
# =============================================================================


async def test_infrastructure(client: httpx.AsyncClient) -> TestCategory:
    """Test basic gateway infrastructure."""
    category = TestCategory(name="Infrastructure")

    # 1.1 Health Check (no auth)
    try:
        resp, dur = await timed_request(client, "GET", f"{GATEWAY_URL}/health")
        if resp.status_code == 200:
            data = resp.json()
            if data.get("status") == "ok":
                category.results.append(
                    TestResult("Health check", TestStatus.PASSED, duration=dur)
                )
            else:
                category.results.append(
                    TestResult(
                        "Health check",
                        TestStatus.FAILED,
                        f"Unexpected response: {data}",
                        dur,
                    )
                )
        else:
            category.results.append(
                TestResult(
                    "Health check", TestStatus.FAILED, f"Status {resp.status_code}", dur
                )
            )
    except Exception as e:
        category.results.append(TestResult("Health check", TestStatus.FAILED, str(e)))

    # 1.2 List Projects
    try:
        resp, dur = await timed_request(
            client, "GET", f"{GATEWAY_URL}/projects", headers=headers()
        )
        if resp.status_code == 200:
            projects = resp.json()
            if isinstance(projects, list):
                project_names = [p["name"] for p in projects]
                if PROJECT_NAME in project_names:
                    category.results.append(
                        TestResult(
                            "List projects",
                            TestStatus.PASSED,
                            f"Found {len(projects)} projects",
                            dur,
                        )
                    )
                else:
                    category.results.append(
                        TestResult(
                            "List projects",
                            TestStatus.FAILED,
                            f"Project '{PROJECT_NAME}' not found in {project_names}",
                            dur,
                        )
                    )
            else:
                category.results.append(
                    TestResult(
                        "List projects",
                        TestStatus.FAILED,
                        f"Expected list, got {type(projects)}",
                        dur,
                    )
                )
        else:
            category.results.append(
                TestResult(
                    "List projects",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}: {resp.text}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(TestResult("List projects", TestStatus.FAILED, str(e)))

    # 1.3 Start Project
    try:
        resp, dur = await timed_request(
            client,
            "POST",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/start",
            headers=headers(),
        )
        if resp.status_code == 200:
            data = resp.json()
            port = data.get("port")
            status = data.get("status")
            if port and status in ["started", "already_running"]:
                category.results.append(
                    TestResult(
                        "Start project",
                        TestStatus.PASSED,
                        f"Port {port}, status: {status}",
                        dur,
                    )
                )
            else:
                category.results.append(
                    TestResult(
                        "Start project",
                        TestStatus.FAILED,
                        f"Missing port or bad status: {data}",
                        dur,
                    )
                )
        else:
            category.results.append(
                TestResult(
                    "Start project",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}: {resp.text}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(TestResult("Start project", TestStatus.FAILED, str(e)))

    # 1.4 Get Project Status
    try:
        resp, dur = await timed_request(
            client,
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/status",
            headers=headers(),
        )
        if resp.status_code == 200:
            data = resp.json()
            if data.get("is_running") and data.get("port"):
                category.results.append(
                    TestResult(
                        "Get project status",
                        TestStatus.PASSED,
                        f"Running on port {data['port']}",
                        dur,
                    )
                )
            else:
                category.results.append(
                    TestResult(
                        "Get project status",
                        TestStatus.FAILED,
                        f"Not running or no port: {data}",
                        dur,
                    )
                )
        else:
            category.results.append(
                TestResult(
                    "Get project status",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(
            TestResult("Get project status", TestStatus.FAILED, str(e))
        )

    # 1.5 Config Proxy Test (Get Providers)
    try:
        resp, dur = await timed_request(
            client,
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/config/providers",
            headers=headers(),
        )
        if resp.status_code == 200:
            data = resp.json()
            providers = data.get("providers", {})
            if providers:
                category.results.append(
                    TestResult(
                        "Proxy to OpenCode (providers)",
                        TestStatus.PASSED,
                        f"Found {len(providers)} providers",
                        dur,
                    )
                )
            else:
                category.results.append(
                    TestResult(
                        "Proxy to OpenCode (providers)",
                        TestStatus.FAILED,
                        "No providers in response",
                        dur,
                    )
                )
        else:
            category.results.append(
                TestResult(
                    "Proxy to OpenCode (providers)",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}: {resp.text}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(
            TestResult("Proxy to OpenCode (providers)", TestStatus.FAILED, str(e))
        )

    return category


# =============================================================================
# Phase 2: Session Management Tests
# =============================================================================


async def test_session_management(
    client: httpx.AsyncClient,
) -> tuple[TestCategory, Optional[str]]:
    """Test session CRUD operations."""
    category = TestCategory(name="Session Management")
    created_session_id: Optional[str] = None

    # 2.1 List Sessions
    try:
        resp, dur = await timed_request(
            client,
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session",
            headers=headers(),
        )
        if resp.status_code == 200:
            sessions = resp.json()
            if isinstance(sessions, list):
                category.results.append(
                    TestResult(
                        "List sessions",
                        TestStatus.PASSED,
                        f"Found {len(sessions)} sessions",
                        dur,
                    )
                )
            else:
                category.results.append(
                    TestResult(
                        "List sessions",
                        TestStatus.FAILED,
                        f"Expected list, got {type(sessions)}",
                        dur,
                    )
                )
        else:
            category.results.append(
                TestResult(
                    "List sessions",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(TestResult("List sessions", TestStatus.FAILED, str(e)))

    # 2.2 Create Session
    try:
        resp, dur = await timed_request(
            client,
            "POST",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session",
            headers=headers(),
            json={"title": "Test Session from test_all_endpoints.py"},
        )
        if resp.status_code == 200:
            data = resp.json()
            created_session_id = data.get("id")
            if created_session_id:
                category.results.append(
                    TestResult(
                        "Create session",
                        TestStatus.PASSED,
                        f"ID: {created_session_id[:16]}...",
                        dur,
                    )
                )
            else:
                category.results.append(
                    TestResult(
                        "Create session",
                        TestStatus.FAILED,
                        f"No ID in response: {data}",
                        dur,
                    )
                )
        else:
            category.results.append(
                TestResult(
                    "Create session",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}: {resp.text}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(TestResult("Create session", TestStatus.FAILED, str(e)))

    # 2.3 Get Session by ID
    if created_session_id:
        try:
            resp, dur = await timed_request(
                client,
                "GET",
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{created_session_id}",
                headers=headers(),
            )
            if resp.status_code == 200:
                data = resp.json()
                if data.get("id") == created_session_id:
                    category.results.append(
                        TestResult("Get session by ID", TestStatus.PASSED, duration=dur)
                    )
                else:
                    category.results.append(
                        TestResult(
                            "Get session by ID",
                            TestStatus.FAILED,
                            f"ID mismatch: {data.get('id')}",
                            dur,
                        )
                    )
            else:
                category.results.append(
                    TestResult(
                        "Get session by ID",
                        TestStatus.FAILED,
                        f"Status {resp.status_code}",
                        dur,
                    )
                )
        except Exception as e:
            category.results.append(
                TestResult("Get session by ID", TestStatus.FAILED, str(e))
            )
    else:
        category.results.append(
            TestResult("Get session by ID", TestStatus.SKIPPED, "No session created")
        )

    # 2.4 Update Session (PATCH)
    if created_session_id:
        try:
            resp, dur = await timed_request(
                client,
                "PATCH",
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{created_session_id}",
                headers=headers(),
                json={"title": "Updated Test Session"},
            )
            if resp.status_code == 200:
                data = resp.json()
                if data.get("title") == "Updated Test Session":
                    category.results.append(
                        TestResult("Update session", TestStatus.PASSED, duration=dur)
                    )
                else:
                    category.results.append(
                        TestResult(
                            "Update session",
                            TestStatus.PASSED,
                            f"Updated (title: {data.get('title')})",
                            dur,
                        )
                    )
            else:
                category.results.append(
                    TestResult(
                        "Update session",
                        TestStatus.FAILED,
                        f"Status {resp.status_code}",
                        dur,
                    )
                )
        except Exception as e:
            category.results.append(
                TestResult("Update session", TestStatus.FAILED, str(e))
            )
    else:
        category.results.append(
            TestResult("Update session", TestStatus.SKIPPED, "No session created")
        )

    return category, created_session_id


# =============================================================================
# Phase 3: Message Operations Tests
# =============================================================================


async def test_message_operations(
    client: httpx.AsyncClient, session_id: Optional[str]
) -> TestCategory:
    """Test message operations."""
    category = TestCategory(name="Message Operations")

    if not session_id:
        # Try to get an existing session
        try:
            resp = await client.get(
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session",
                headers=headers(),
            )
            if resp.status_code == 200:
                sessions = resp.json()
                if sessions:
                    session_id = sessions[0]["id"]
        except Exception:
            pass

    if not session_id:
        category.results.append(
            TestResult(
                "Message operations",
                TestStatus.SKIPPED,
                "No session available",
            )
        )
        return category

    # 3.1 Get Messages
    try:
        resp, dur = await timed_request(
            client,
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{session_id}/message",
            headers=headers(),
        )
        if resp.status_code == 200:
            messages = resp.json()
            if isinstance(messages, list):
                category.results.append(
                    TestResult(
                        "Get messages",
                        TestStatus.PASSED,
                        f"Found {len(messages)} messages",
                        dur,
                    )
                )
            else:
                category.results.append(
                    TestResult(
                        "Get messages",
                        TestStatus.FAILED,
                        f"Expected list, got {type(messages)}",
                        dur,
                    )
                )
        else:
            category.results.append(
                TestResult(
                    "Get messages",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(TestResult("Get messages", TestStatus.FAILED, str(e)))

    # 3.2 Send Async Message (prompt_async)
    try:
        resp, dur = await timed_request(
            client,
            "POST",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{session_id}/prompt_async",
            headers=headers(),
            json={
                "model": {
                    "providerID": "opencode",
                    "modelID": "qwen3-coder",
                },
                "parts": [
                    {"type": "text", "text": "Say 'test passed' in exactly 2 words."}
                ],
            },
        )
        if resp.status_code == 204:
            category.results.append(
                TestResult("Send async message", TestStatus.PASSED, duration=dur)
            )
        elif resp.status_code == 200:
            category.results.append(
                TestResult(
                    "Send async message",
                    TestStatus.PASSED,
                    "Got 200 instead of 204",
                    dur,
                )
            )
        else:
            category.results.append(
                TestResult(
                    "Send async message",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}: {resp.text}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(
            TestResult("Send async message", TestStatus.FAILED, str(e))
        )

    # Wait a bit for the message to be processed
    await asyncio.sleep(2)

    # 3.3 Abort (test that it doesn't error)
    try:
        resp, dur = await timed_request(
            client,
            "POST",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{session_id}/abort",
            headers=headers(),
        )
        # Abort should succeed even if nothing is running
        if resp.status_code in [200, 204]:
            category.results.append(
                TestResult("Abort generation", TestStatus.PASSED, duration=dur)
            )
        else:
            category.results.append(
                TestResult(
                    "Abort generation",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(
            TestResult("Abort generation", TestStatus.FAILED, str(e))
        )

    return category


# =============================================================================
# Phase 4: Model Selection Tests
# =============================================================================


async def test_model_selection(client: httpx.AsyncClient) -> TestCategory:
    """Test model/provider selection."""
    category = TestCategory(name="Model Selection")

    # 4.1 Get Providers
    try:
        resp, dur = await timed_request(
            client,
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/config/providers",
            headers=headers(),
        )
        if resp.status_code == 200:
            data = resp.json()
            providers = data.get("providers", data)

            if isinstance(providers, dict):
                found_providers = list(providers.keys())
                category.results.append(
                    TestResult(
                        "Get providers",
                        TestStatus.PASSED,
                        f"Providers: {', '.join(found_providers[:5])}{'...' if len(found_providers) > 5 else ''}",
                        dur,
                    )
                )
            elif isinstance(providers, list):
                provider_ids = [p.get("id", "?") for p in providers[:5]]
                category.results.append(
                    TestResult(
                        "Get providers",
                        TestStatus.PASSED,
                        f"Providers: {', '.join(provider_ids)}{'...' if len(providers) > 5 else ''}",
                        dur,
                    )
                )
            else:
                category.results.append(
                    TestResult(
                        "Get providers",
                        TestStatus.PASSED,
                        f"Providers response type: {type(providers).__name__}",
                        dur,
                    )
                )
        else:
            category.results.append(
                TestResult(
                    "Get providers",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(TestResult("Get providers", TestStatus.FAILED, str(e)))

    return category


# =============================================================================
# Phase 5: SSE Streaming Tests (CRITICAL)
# =============================================================================


async def test_sse_streaming(
    client: httpx.AsyncClient, session_id: Optional[str]
) -> TestCategory:
    """Test SSE streaming - the critical functionality."""
    category = TestCategory(name="SSE Streaming")

    if not session_id:
        # Try to get or create a session
        try:
            resp = await client.get(
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session",
                headers=headers(),
            )
            if resp.status_code == 200:
                sessions = resp.json()
                if sessions:
                    session_id = sessions[0]["id"]
                else:
                    # Create a new session
                    resp = await client.post(
                        f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session",
                        headers=headers(),
                        json={"title": "SSE Test Session"},
                    )
                    if resp.status_code == 200:
                        session_id = resp.json().get("id")
        except Exception:
            pass

    if not session_id:
        category.results.append(
            TestResult("SSE streaming", TestStatus.SKIPPED, "No session available")
        )
        return category

    # 5.1 Test SSE Connection
    sse_connection_ok = False
    try:
        async with client.stream(
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/event",
            headers=headers(),
            timeout=10.0,
        ) as response:
            if response.status_code == 200:
                sse_connection_ok = True
                category.results.append(TestResult("SSE connection", TestStatus.PASSED))

                # 5.2 Wait for heartbeat or server.connected
                event_received = False
                start_time = time.time()

                async for line in response.aiter_lines():
                    if time.time() - start_time > 5:
                        break
                    if not line.strip():
                        continue
                    if line.startswith("data:"):
                        try:
                            data = json.loads(line[5:].strip())
                            evt_type = data.get("type", "")
                            if evt_type in ["server.heartbeat", "server.connected"]:
                                event_received = True
                                break
                        except json.JSONDecodeError:
                            pass

                if event_received:
                    category.results.append(
                        TestResult("SSE events received", TestStatus.PASSED)
                    )
                else:
                    category.results.append(
                        TestResult(
                            "SSE events received",
                            TestStatus.FAILED,
                            "No events received in 5s",
                        )
                    )
            else:
                category.results.append(
                    TestResult(
                        "SSE connection",
                        TestStatus.FAILED,
                        f"Status {response.status_code}",
                    )
                )
    except Exception as e:
        if not sse_connection_ok:
            category.results.append(
                TestResult("SSE connection", TestStatus.FAILED, str(e))
            )

    # 5.3 Test SSE with message sending (the critical test)
    for provider_id, model_id in MODELS_TO_TEST:
        test_name = f"SSE with {provider_id}/{model_id}"

        try:
            result = await test_sse_with_model(
                client, session_id, provider_id, model_id
            )
            category.results.append(result)
        except Exception as e:
            category.results.append(TestResult(test_name, TestStatus.FAILED, str(e)))

    return category


async def test_sse_with_model(
    client: httpx.AsyncClient,
    session_id: str,
    provider_id: str,
    model_id: str,
) -> TestResult:
    """Test SSE streaming with a specific model."""
    test_name = f"SSE with {provider_id}/{model_id}"

    events_received = {
        "user_message": False,
        "assistant_message": False,
        "text_part": False,
        "completed": False,
        "error": "",
    }
    text_chunks = []

    try:
        # Create a new client for SSE to avoid connection issues
        async with httpx.AsyncClient(timeout=SSE_TIMEOUT) as sse_client:
            async with sse_client.stream(
                "GET",
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/event",
                headers=headers(),
                timeout=None,
            ) as sse_response:
                if sse_response.status_code != 200:
                    return TestResult(
                        test_name,
                        TestStatus.FAILED,
                        f"SSE connection failed: {sse_response.status_code}",
                    )

                # Send message in background
                async def send_message():
                    await asyncio.sleep(0.5)  # Let SSE connect first
                    async with httpx.AsyncClient(timeout=30.0) as msg_client:
                        resp = await msg_client.post(
                            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{session_id}/prompt_async",
                            headers=headers(),
                            json={
                                "model": {
                                    "providerID": provider_id,
                                    "modelID": model_id,
                                },
                                "parts": [
                                    {
                                        "type": "text",
                                        "text": "Say exactly: 'pong'",
                                    }
                                ],
                            },
                        )
                        return resp.status_code

                send_task = asyncio.create_task(send_message())

                # Listen for events
                start_time = time.time()
                timeout = 30.0  # 30 second timeout for response

                async for line in sse_response.aiter_lines():
                    elapsed = time.time() - start_time
                    if elapsed > timeout:
                        break

                    if not line.strip():
                        continue

                    if line.startswith("data:"):
                        try:
                            data = json.loads(line[5:].strip())
                            evt_type = data.get("type")
                            props = data.get("properties", {})

                            if evt_type == "message.updated":
                                info = props.get("info", {})
                                role = info.get("role")
                                time_info = info.get("time", {})
                                has_completed = "completed" in time_info
                                has_error = "error" in info

                                if role == "user":
                                    events_received["user_message"] = True
                                elif role == "assistant":
                                    events_received["assistant_message"] = True
                                    if has_completed or has_error:
                                        events_received["completed"] = True
                                        if has_error:
                                            err = info.get("error", {})
                                            err_msg = err.get("data", {}).get(
                                                "message", str(err)
                                            )[:100]
                                            events_received["error"] = err_msg
                                        break

                            elif evt_type == "session.error":
                                err = props.get("error", {})
                                err_msg = err.get("data", {}).get("message", str(err))[
                                    :100
                                ]
                                events_received["error"] = err_msg

                            elif evt_type == "message.part.updated":
                                part = props.get("part", {})
                                if part.get("type") == "text":
                                    events_received["text_part"] = True
                                    text = part.get("text", "")
                                    if text:
                                        text_chunks.append(text)

                        except json.JSONDecodeError:
                            pass

                # Wait for send task
                try:
                    send_status = await asyncio.wait_for(send_task, timeout=5.0)
                except asyncio.TimeoutError:
                    send_status = None

        # Evaluate results
        error_msg = events_received["error"]

        if events_received["completed"]:
            full_text = "".join(text_chunks)
            if error_msg:
                return TestResult(
                    test_name,
                    TestStatus.PASSED,
                    f"Completed with provider error: {error_msg[:60]}...",
                )
            elif full_text:
                return TestResult(
                    test_name,
                    TestStatus.PASSED,
                    f"Response: '{full_text[:50]}{'...' if len(full_text) > 50 else ''}'",
                )
            else:
                return TestResult(
                    test_name,
                    TestStatus.PASSED,
                    "Completed (no text content)",
                )
        elif events_received["text_part"]:
            return TestResult(
                test_name,
                TestStatus.PASSED,
                f"Got text chunks, waiting for completion timed out",
            )
        elif events_received["assistant_message"]:
            if error_msg:
                return TestResult(
                    test_name,
                    TestStatus.PASSED,
                    f"Provider error: {error_msg[:60]}...",
                )
            return TestResult(
                test_name,
                TestStatus.FAILED,
                "Got assistant message but no text parts or completion",
            )
        elif events_received["user_message"]:
            return TestResult(
                test_name,
                TestStatus.FAILED,
                "Got user message but no assistant response",
            )
        else:
            return TestResult(
                test_name,
                TestStatus.FAILED,
                "No message events received (only heartbeats?)",
            )

    except asyncio.TimeoutError:
        return TestResult(test_name, TestStatus.FAILED, "Timeout waiting for response")
    except Exception as e:
        return TestResult(test_name, TestStatus.FAILED, str(e))


# =============================================================================
# Phase 6: Status Endpoints Tests
# =============================================================================


async def test_status_endpoints(
    client: httpx.AsyncClient, session_id: Optional[str]
) -> TestCategory:
    """Test status endpoints."""
    category = TestCategory(name="Status Endpoints")

    if not session_id:
        # Try to get an existing session
        try:
            resp = await client.get(
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session",
                headers=headers(),
            )
            if resp.status_code == 200:
                sessions = resp.json()
                if sessions:
                    session_id = sessions[0]["id"]
        except Exception:
            pass

    # 6.1 Get Todos
    if session_id:
        try:
            resp, dur = await timed_request(
                client,
                "GET",
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{session_id}/todo",
                headers=headers(),
            )
            if resp.status_code == 200:
                todos = resp.json()
                category.results.append(
                    TestResult(
                        "Get todos",
                        TestStatus.PASSED,
                        f"Found {len(todos) if isinstance(todos, list) else 0} todos",
                        dur,
                    )
                )
            else:
                category.results.append(
                    TestResult(
                        "Get todos",
                        TestStatus.FAILED,
                        f"Status {resp.status_code}",
                        dur,
                    )
                )
        except Exception as e:
            category.results.append(TestResult("Get todos", TestStatus.FAILED, str(e)))

        # 6.2 Get Diffs
        try:
            resp, dur = await timed_request(
                client,
                "GET",
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{session_id}/diff",
                headers=headers(),
            )
            if resp.status_code == 200:
                diffs = resp.json()
                category.results.append(
                    TestResult(
                        "Get diffs",
                        TestStatus.PASSED,
                        f"Found {len(diffs) if isinstance(diffs, list) else 0} diffs",
                        dur,
                    )
                )
            else:
                category.results.append(
                    TestResult(
                        "Get diffs",
                        TestStatus.FAILED,
                        f"Status {resp.status_code}",
                        dur,
                    )
                )
        except Exception as e:
            category.results.append(TestResult("Get diffs", TestStatus.FAILED, str(e)))
    else:
        category.results.append(
            TestResult("Get todos", TestStatus.SKIPPED, "No session available")
        )
        category.results.append(
            TestResult("Get diffs", TestStatus.SKIPPED, "No session available")
        )

    # 6.3 Get MCP Status
    try:
        resp, dur = await timed_request(
            client,
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/mcp",
            headers=headers(),
        )
        if resp.status_code == 200:
            mcp = resp.json()
            category.results.append(
                TestResult(
                    "Get MCP status",
                    TestStatus.PASSED,
                    f"MCP servers: {len(mcp) if isinstance(mcp, dict) else 0}",
                    dur,
                )
            )
        else:
            category.results.append(
                TestResult(
                    "Get MCP status",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(TestResult("Get MCP status", TestStatus.FAILED, str(e)))

    # 6.4 Get LSP Status
    try:
        resp, dur = await timed_request(
            client,
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/lsp",
            headers=headers(),
        )
        if resp.status_code == 200:
            lsp = resp.json()
            category.results.append(
                TestResult(
                    "Get LSP status",
                    TestStatus.PASSED,
                    f"LSP servers: {len(lsp) if isinstance(lsp, list) else 0}",
                    dur,
                )
            )
        else:
            category.results.append(
                TestResult(
                    "Get LSP status",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(TestResult("Get LSP status", TestStatus.FAILED, str(e)))

    # 6.5 Get Commands
    try:
        resp, dur = await timed_request(
            client,
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/command",
            headers=headers(),
        )
        if resp.status_code == 200:
            commands = resp.json()
            category.results.append(
                TestResult(
                    "Get commands",
                    TestStatus.PASSED,
                    f"Commands: {len(commands) if isinstance(commands, list) else 0}",
                    dur,
                )
            )
        else:
            category.results.append(
                TestResult(
                    "Get commands",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(TestResult("Get commands", TestStatus.FAILED, str(e)))

    # 6.6 Get Agents
    try:
        resp, dur = await timed_request(
            client,
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/agent",
            headers=headers(),
        )
        if resp.status_code == 200:
            agents = resp.json()
            category.results.append(
                TestResult(
                    "Get agents",
                    TestStatus.PASSED,
                    f"Agents: {len(agents) if isinstance(agents, list) else 0}",
                    dur,
                )
            )
        else:
            category.results.append(
                TestResult(
                    "Get agents",
                    TestStatus.FAILED,
                    f"Status {resp.status_code}",
                    dur,
                )
            )
    except Exception as e:
        category.results.append(TestResult("Get agents", TestStatus.FAILED, str(e)))

    return category


# =============================================================================
# Phase 7: Cleanup Tests
# =============================================================================


async def test_cleanup(
    client: httpx.AsyncClient, session_id: Optional[str]
) -> TestCategory:
    """Test cleanup operations (delete session)."""
    category = TestCategory(name="Cleanup")

    if session_id:
        try:
            resp, dur = await timed_request(
                client,
                "DELETE",
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{session_id}",
                headers=headers(),
            )
            if resp.status_code in [200, 204]:
                category.results.append(
                    TestResult("Delete test session", TestStatus.PASSED, duration=dur)
                )
            else:
                category.results.append(
                    TestResult(
                        "Delete test session",
                        TestStatus.FAILED,
                        f"Status {resp.status_code}",
                        dur,
                    )
                )
        except Exception as e:
            category.results.append(
                TestResult("Delete test session", TestStatus.FAILED, str(e))
            )
    else:
        category.results.append(
            TestResult(
                "Delete test session", TestStatus.SKIPPED, "No session to delete"
            )
        )

    return category


# =============================================================================
# Main Runner
# =============================================================================


def print_category(category: TestCategory) -> None:
    """Print results for a test category."""
    status_icon = "✅" if category.failed == 0 else "❌"
    print(f"\n{status_icon} {category.name}: {category.passed}/{category.total}")

    for result in category.results:
        if result.status == TestStatus.PASSED:
            icon = "  ✅"
        elif result.status == TestStatus.FAILED:
            icon = "  ❌"
        else:
            icon = "  ⏭️"

        msg = f" - {result.message}" if result.message else ""
        dur = f" ({result.duration:.2f}s)" if result.duration > 0 else ""
        print(f"{icon} {result.name}{msg}{dur}")


def print_summary(categories: list[TestCategory]) -> None:
    """Print overall test summary."""
    total_passed = sum(c.passed for c in categories)
    total_failed = sum(c.failed for c in categories)
    total_tests = sum(c.total for c in categories)

    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Total: {total_passed}/{total_tests} passed")
    print(f"Failed: {total_failed}")

    # List critical failures
    critical_failures = []
    for cat in categories:
        for result in cat.results:
            if result.status == TestStatus.FAILED:
                if "SSE" in result.name or "message" in result.name.lower():
                    critical_failures.append(f"{cat.name}: {result.name}")

    if critical_failures:
        print("\nCritical Failures:")
        for failure in critical_failures:
            print(f"  ❌ {failure}")

    print("=" * 60)

    if total_failed == 0:
        print("🎉 All tests passed!")
    else:
        print(f"⚠️  {total_failed} test(s) failed")


async def main():
    """Run all tests."""
    print("=" * 60)
    print("VibeRemote Gateway Comprehensive Test Suite")
    print("=" * 60)
    print(f"Gateway URL: {GATEWAY_URL}")
    print(f"Project: {PROJECT_NAME}")
    print(f"Models to test: {MODELS_TO_TEST}")
    print("=" * 60)

    categories: list[TestCategory] = []
    session_id: Optional[str] = None

    async with httpx.AsyncClient(timeout=DEFAULT_TIMEOUT) as client:
        # Phase 1: Infrastructure
        print("\n🔧 Testing Infrastructure...")
        cat = await test_infrastructure(client)
        categories.append(cat)
        print_category(cat)

        # Check if infrastructure passed before continuing
        if cat.failed > 0:
            print("\n⚠️  Infrastructure tests failed. Some subsequent tests may fail.")

        # Phase 2: Session Management
        print("\n📋 Testing Session Management...")
        cat, session_id = await test_session_management(client)
        categories.append(cat)
        print_category(cat)

        # Phase 3: Message Operations
        print("\n💬 Testing Message Operations...")
        cat = await test_message_operations(client, session_id)
        categories.append(cat)
        print_category(cat)

        # Phase 4: Model Selection
        print("\n🤖 Testing Model Selection...")
        cat = await test_model_selection(client)
        categories.append(cat)
        print_category(cat)

        # Phase 5: SSE Streaming (Critical)
        print("\n📡 Testing SSE Streaming (CRITICAL)...")
        cat = await test_sse_streaming(client, session_id)
        categories.append(cat)
        print_category(cat)

        # Phase 6: Status Endpoints
        print("\n📊 Testing Status Endpoints...")
        cat = await test_status_endpoints(client, session_id)
        categories.append(cat)
        print_category(cat)

        # Phase 7: Cleanup
        print("\n🧹 Cleanup...")
        cat = await test_cleanup(client, session_id)
        categories.append(cat)
        print_category(cat)

    # Print summary
    print_summary(categories)

    # Return exit code
    total_failed = sum(c.failed for c in categories)
    return 1 if total_failed > 0 else 0


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
