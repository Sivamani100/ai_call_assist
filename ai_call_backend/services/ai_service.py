# services/ai_service.py
import anthropic
import json
import os
from typing import AsyncGenerator

client = anthropic.AsyncAnthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))
CLAUDE_MODEL = 'claude-haiku-4-5'  # Fast, cheap, ideal for phone conversations

async def get_ai_response_stream(messages: list) -> AsyncGenerator[str, None]:
    """Stream Claude response token by token during live call."""
    system_msg = next((m['content'] for m in messages if m['role'] == 'system'), '')
    conversation = [m for m in messages if m['role'] != 'system']

    async with client.messages.stream(
        model=CLAUDE_MODEL,
        max_tokens=300,   # Keep responses SHORT — this is a phone call
        system=system_msg,
        messages=conversation,
    ) as stream:
        async for text in stream.text_stream:
            yield text

async def generate_call_summary(transcript: list, caller_name: str,
                                  caller_number: str) -> dict:
    """Generate structured JSON summary after call ends. NOT streamed."""
    from prompts.summary_prompt import build_summary_prompt
    transcript_text = '\n'.join(
        f"{'CALLER' if t['speaker'] == 'caller' else 'ASSISTANT'}: {t['text']}"
        for t in transcript
    )
    prompt = build_summary_prompt(transcript_text, caller_name, caller_number)
    response = await client.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=600,
        messages=[{'role': 'user', 'content': prompt}]
    )
    text = response.content[0].text.strip()
    if text.startswith('```'):  # Strip markdown fences if present
        text = text.split('\n', 1)[1].rsplit('```', 1)[0]
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {
            'summary': text[:200], 'caller_name': caller_name,
            'purpose': 'Unknown', 'urgency': 'low',
            'call_type': 'routine', 'action_needed': 'Review call',
            'recommended_response': '', 'should_call_back': False
        }
