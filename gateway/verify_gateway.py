import asyncio
import json
import os
import httpx
import sys

# Configuration
GATEWAY_URL = "http://127.0.0.1:4000"
API_KEY = "fb9b4ae8e769f297ee785f191d599c579552a12bd87f77bba12da3df2d249b0f"
PROJECT_NAME = "Test"

headers = {"Authorization": f"Bearer {API_KEY}"}


async def run_tests():
    print(f"🚀 Starting Headless Verification for {GATEWAY_URL}")

    async with httpx.AsyncClient(timeout=30.0) as client:
        # 1. Health Check
        print("\n--- 1. Gateway Health Check ---")
        try:
            resp = await client.get(f"{GATEWAY_URL}/health")
            print(f"Status: {resp.status_code}")
            print(f"Response: {resp.json()}")
            if resp.status_code != 200:
                print("❌ Gateway Health Check Failed")
                return
        except Exception as e:
            print(f"❌ Connection Failed: {e}")
            return

        # 2. List Projects
        print("\n--- 2. List Projects ---")
        resp = await client.get(f"{GATEWAY_URL}/projects", headers=headers)
        print(f"Status: {resp.status_code}")
        projects = resp.json()
        print(f"Found {len(projects)} projects")
        target_project = next((p for p in projects if p["name"] == PROJECT_NAME), None)
        if not target_project:
            print(f"❌ Project '{PROJECT_NAME}' not found!")
            return
        print(
            f"✅ Found project '{PROJECT_NAME}' (Running: {target_project['is_running']}, Port: {target_project['port']})"
        )

        # 3. Start/Connect Session
        print(f"\n--- 3. Start/Connect to '{PROJECT_NAME}' ---")
        resp = await client.post(
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/start", headers=headers
        )
        print(f"Status: {resp.status_code}")
        start_data = resp.json()
        print(f"Response: {start_data}")
        current_port = start_data["port"]
        print(f"✅ Active Port: {current_port}")

        # 4. Get Providers (Config)
        print("\n--- 4. Fetch Providers (Proxy Test) ---")
        try:
            resp = await client.get(
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/config/providers",
                headers=headers,
            )
            print(f"Status: {resp.status_code}")
            if resp.status_code == 200:
                data = resp.json()
                provider_count = len(data.get("providers", {}))
                print(f"✅ Proxy Working! Found {provider_count} providers")
            else:
                print(f"❌ Failed to fetch providers: {resp.text}")
        except Exception as e:
            print(f"❌ Proxy Request Failed: {e}")

        # 5. Restart Cycle (Resilience Test)
        print("\n--- 5. Testing Restart Cycle (The Fix) ---")
        print("Stopping...")
        resp = await client.delete(
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/stop", headers=headers
        )
        print(f"Stop Status: {resp.status_code}")

        print("Starting (forcing new port allocation)...")
        # Start immediately
        resp = await client.post(
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/start", headers=headers
        )
        print(f"Start Status: {resp.status_code}")
        restart_data = resp.json()
        new_port = restart_data["port"]
        print(f"New Port: {new_port}")

        if new_port != current_port:
            print(
                f"✅ SUCCESS: Port changed from {current_port} -> {new_port} and Gateway detected it!"
            )
        else:
            print(
                f"⚠️ Port remained {current_port} (Server might have reused it, or Gateway logic issue)"
            )

        # 6. Chat Test (SSE)
        print("\n--- 6. Chat Test (SSE & LLM Response) ---")
        # Get or create session ID
        resp = await client.get(
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session", headers=headers
        )
        sessions = resp.json()
        if sessions:
            session_id = sessions[0]["id"]
            print(f"Using existing session: {session_id}")
        else:
            print("Creating new session...")
            resp = await client.post(
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session",
                headers=headers,
                json={"path": "."},
            )
            session_id = resp.json()["id"]
            print(f"Created session: {session_id}")

        # Connect to SSE
        print("Connecting to SSE stream...")
        async with client.stream(
            "GET",
            f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/event",
            headers=headers,
            timeout=None,
        ) as response:
            print("✅ SSE Connected")

            # Send Message in parallel task
            async def send_msg():
                await asyncio.sleep(1)  # Wait for connection
                print("Sending 'Hello' to LLM...")
                msg_body = {
                    "modelID": "big-pickle",  # Fast model for test
                    "providerID": "opencode",
                    "parts": [
                        {"type": "text", "text": "Hello, say 'pong' if you hear me."}
                    ],
                }
                r = await client.post(
                    f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{session_id}/prompt_async",
                    headers=headers,
                    json=msg_body,
                )
                print(f"Message Sent: {r.status_code}")

            asyncio.create_task(send_msg())

            print("Listening for events (timeout 10s)...")
            start_time = asyncio.get_event_loop().time()
            received_response = False

            async for line in response.aiter_lines():
                if not line.strip():
                    continue
                if line.startswith("data:"):
                    data_str = line[5:].strip()
                    try:
                        event = json.loads(data_str)
                        evt_type = event.get("type")

                        if evt_type == "message.part.updated":
                            part = event["properties"]["part"]
                            if part.get("type") == "text":
                                print(f"🔹 LLM Chunk: {part.get('text', '')}")
                                received_response = True
                        elif (
                            evt_type == "message.updated"
                            and event["properties"]["info"]["role"] == "assistant"
                        ):
                            print("🔹 Assistant Message Updated")

                    except:
                        pass

                if received_response and (
                    asyncio.get_event_loop().time() - start_time > 5
                ):
                    print("✅ Received LLM response chunks!")
                    break

                if asyncio.get_event_loop().time() - start_time > 15:
                    print("❌ Timeout waiting for LLM response")
                    break


if __name__ == "__main__":
    asyncio.run(run_tests())
