import asyncio
import json
import httpx
import sys

GATEWAY_URL = "http://127.0.0.1:4000"
API_KEY = "fb9b4ae8e769f297ee785f191d599c579552a12bd87f77bba12da3df2d249b0f"
PROJECT_NAME = "Test"
MODEL_ID = "big-pickle"

headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}


async def run_full_chat_test():
    print(f"Starting Deep Chat Verification on {GATEWAY_URL}")

    async with httpx.AsyncClient(timeout=60.0) as client:
        print("\n--- 1. Ensuring Project is Running ---")
        try:
            resp = await client.post(
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/start", headers=headers
            )
            if resp.status_code != 200:
                print(f"Failed to start project: {resp.text}")
                return
            data = resp.json()
            print(f"Project Running on Port: {data['port']}")
        except Exception as e:
            print(f"Connection Error: {e}")
            return

        print("\n--- 2. Creating OpenCode Session ---")
        try:
            resp = await client.get(
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session", headers=headers
            )
            sessions = resp.json()
            if sessions:
                session_id = sessions[0]["id"]
                print(f"Using existing session: {session_id}")
            else:
                resp = await client.post(
                    f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session",
                    headers=headers,
                    json={"path": "."},
                )
                session_id = resp.json()["id"]
                print(f"Created new session: {session_id}")
        except Exception as e:
            print(f"Session Error: {e}")
            return

        print("\n--- 3. Connecting to Event Stream ---")

        prompt_url = f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/session/{session_id}/prompt_async"
        prompt_body = {
            "modelID": MODEL_ID,
            "providerID": "opencode",
            "parts": [
                {
                    "type": "text",
                    "text": "Please count to 3 step by step and explain your logic. Use a thinking process.",
                }
            ],
        }

        found_thinking = False
        found_response = False

        try:
            async with client.stream(
                "GET",
                f"{GATEWAY_URL}/projects/{PROJECT_NAME}/api/event",
                headers=headers,
                timeout=None,
            ) as stream:
                print("SSE Stream Connected")

                print(f"URL: {prompt_url}")
                print(f"Body: {json.dumps(prompt_body)}")
                r = await client.post(prompt_url, headers=headers, json=prompt_body)
                print(f"Status Code: {r.status_code}")
                if r.status_code in [200, 204]:
                    print("Prompt Sent Successfully")
                else:
                    print(f"Failed to send prompt: {r.text}")
                    return

                print("\n--- 5. Listening for Response & Thinking ---")
                async for line in stream.aiter_lines():
                    if not line.strip():
                        continue
                    if line.startswith("data:"):
                        data_str = line[5:].strip()
                        try:
                            event = json.loads(data_str)
                            evt_type = event.get("type")

                            if evt_type == "message.part.updated":
                                props = event.get("properties", {})
                                part = props.get("part", {})
                                p_type = part.get("type")
                                p_content = part.get("text", "") or part.get(
                                    "reasoning", ""
                                )

                                if p_type == "reasoning" or p_type == "thought":
                                    if not found_thinking:
                                        print("\n[THINKING STARTED]")
                                        found_thinking = True
                                    print(f"   Thinking chunk received", end="\r")

                                if p_type == "text":
                                    if not found_response:
                                        print("\n[RESPONSE STARTED]")
                                        found_response = True
                                    print(f"   Response chunk received", end="\r")

                            if evt_type == "message.updated":
                                info = event.get("properties", {}).get("info", {})
                                if info.get("role") == "assistant" and info.get(
                                    "completed"
                                ):
                                    print("\n\nAssistant Message Completed")
                                    break

                        except json.JSONDecodeError:
                            pass

                print("\n--- Test Summary ---")
                print(f"Thinking Detected: {found_thinking}")
                print(f"Response Detected: {found_response}")

        except Exception as e:
            print(f"\nStream/Test Failed: {e}")


if __name__ == "__main__":
    asyncio.run(run_full_chat_test())
