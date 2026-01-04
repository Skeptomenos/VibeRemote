#!/usr/bin/env python3
"""
SSE Debug Script - Compare direct OpenCode SSE vs Gateway-proxied SSE

This script tests SSE streaming by:
1. Connecting to SSE stream
2. Sending a message
3. Logging ALL events received

Run locally: python debug_sse.py --gateway
Run on server: python debug_sse.py --direct --port 34441
"""

import asyncio
import json
import sys
import time
from typing import Optional

import httpx

API_KEY = "fb9b4ae8e769f297ee785f191d599c579552a12bd87f77bba12da3df2d249b0f"
PROJECT_NAME = "Test"


def headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}


async def get_or_create_session(base_url: str, use_auth: bool) -> Optional[str]:
    """Get existing session or create new one."""
    hdrs = headers() if use_auth else {"Content-Type": "application/json"}

    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(f"{base_url}/session", headers=hdrs)
        if resp.status_code == 200:
            sessions = resp.json()
            if sessions:
                return sessions[0]["id"]

        resp = await client.post(
            f"{base_url}/session",
            headers=hdrs,
            json={"title": "SSE Debug Session"},
        )
        if resp.status_code == 200:
            return resp.json().get("id")

    return None


async def test_sse(
    base_url: str,
    session_id: str,
    use_auth: bool,
    label: str,
) -> None:
    """Test SSE streaming and log all events."""
    hdrs = headers() if use_auth else {"Content-Type": "application/json"}
    sse_hdrs = {"Authorization": f"Bearer {API_KEY}"} if use_auth else {}

    print(f"\n{'=' * 60}")
    print(f"Testing SSE: {label}")
    print(f"Base URL: {base_url}")
    print(f"Session ID: {session_id}")
    print(f"{'=' * 60}")

    events_by_type: dict[str, int] = {}
    message_events: list[dict] = []

    try:
        async with httpx.AsyncClient(timeout=None) as client:
            print("\n[1] Connecting to SSE stream...")

            async with client.stream(
                "GET",
                f"{base_url}/event",
                headers=sse_hdrs,
                timeout=None,
            ) as sse_response:
                print(f"    SSE Status: {sse_response.status_code}")

                if sse_response.status_code != 200:
                    print(f"    ERROR: SSE connection failed")
                    return

                print("    SSE Connected!")

                async def send_message():
                    await asyncio.sleep(1.0)
                    print("\n[2] Sending test message...")
                    async with httpx.AsyncClient(timeout=30.0) as msg_client:
                        resp = await msg_client.post(
                            f"{base_url}/session/{session_id}/prompt_async",
                            headers=hdrs,
                            json={
                                "modelID": "big-pickle",
                                "providerID": "opencode",
                                "parts": [{"type": "text", "text": "Say 'pong'"}],
                            },
                        )
                        print(f"    Message sent: {resp.status_code}")
                        return resp.status_code

                send_task = asyncio.create_task(send_message())

                print("\n[3] Listening for events (30s timeout)...")
                start_time = time.time()

                async for line in sse_response.aiter_lines():
                    elapsed = time.time() - start_time
                    if elapsed > 30:
                        print("\n    TIMEOUT: 30 seconds elapsed")
                        break

                    if not line.strip():
                        continue

                    if line.startswith("data:"):
                        data_str = line[5:].strip()
                        try:
                            event = json.loads(data_str)
                            evt_type = event.get("type", "unknown")

                            events_by_type[evt_type] = (
                                events_by_type.get(evt_type, 0) + 1
                            )

                            if evt_type == "server.heartbeat":
                                if events_by_type[evt_type] <= 2:
                                    print(f"    [{elapsed:.1f}s] {evt_type}")
                                elif events_by_type[evt_type] == 3:
                                    print(
                                        f"    [{elapsed:.1f}s] {evt_type} (suppressing further heartbeats...)"
                                    )
                            elif evt_type == "message.updated":
                                props = event.get("properties", {})
                                info = props.get("info", {})
                                role = info.get("role", "?")
                                completed = info.get("completed", False)
                                msg_id = info.get("id", "?")[:16]
                                print(
                                    f"    [{elapsed:.1f}s] {evt_type}: role={role}, completed={completed}, id={msg_id}..."
                                )
                                message_events.append(event)

                                if role == "assistant" and completed:
                                    print(
                                        "\n    SUCCESS: Got completed assistant message!"
                                    )
                                    break
                            elif evt_type == "message.part.updated":
                                props = event.get("properties", {})
                                part = props.get("part", {})
                                part_type = part.get("type", "?")
                                text = part.get("text", "")[:50]
                                print(
                                    f"    [{elapsed:.1f}s] {evt_type}: type={part_type}, text='{text}'"
                                )
                                message_events.append(event)
                            else:
                                print(f"    [{elapsed:.1f}s] {evt_type}")

                        except json.JSONDecodeError as e:
                            print(f"    [{elapsed:.1f}s] JSON Error: {e}")
                            print(f"    Raw: {data_str[:100]}")
                    else:
                        print(f"    Non-data line: {line[:50]}")

                try:
                    await asyncio.wait_for(send_task, timeout=5.0)
                except asyncio.TimeoutError:
                    pass

        print(f"\n{'=' * 60}")
        print("SUMMARY")
        print(f"{'=' * 60}")
        print(f"Events by type: {events_by_type}")
        print(f"Message events received: {len(message_events)}")

        if message_events:
            print("\nMessage events detail:")
            for evt in message_events[:5]:
                print(
                    f"  - {evt.get('type')}: {json.dumps(evt.get('properties', {}))[:100]}..."
                )
        else:
            print("\nNO MESSAGE EVENTS RECEIVED!")
            print("This confirms the SSE proxy issue.")

    except Exception as e:
        print(f"\nERROR: {e}")
        import traceback

        traceback.print_exc()


async def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "--gateway"

    if mode == "--gateway":
        base_url = f"https://vibecode.helmus.me/projects/{PROJECT_NAME}/api"
        use_auth = True
        label = "Gateway-Proxied SSE"
    elif mode == "--direct":
        port = sys.argv[2] if len(sys.argv) > 2 else "34441"
        base_url = f"http://127.0.0.1:{port}"
        use_auth = False
        label = f"Direct OpenCode SSE (port {port})"
    else:
        print(f"Usage: {sys.argv[0]} [--gateway | --direct <port>]")
        sys.exit(1)

    print(f"Mode: {label}")
    print(f"Base URL: {base_url}")

    session_id = await get_or_create_session(base_url, use_auth)
    if not session_id:
        print("ERROR: Could not get or create session")
        sys.exit(1)

    print(f"Session ID: {session_id}")

    await test_sse(base_url, session_id, use_auth, label)


if __name__ == "__main__":
    asyncio.run(main())
