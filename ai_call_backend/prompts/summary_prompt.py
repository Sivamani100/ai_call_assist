# prompts/summary_prompt.py
def build_summary_prompt(transcript_text: str, caller_name: str, caller_number: str) -> str:
    return f"""Analyse this phone call transcript and return ONLY a JSON object.
No markdown, no explanation, no preamble — pure JSON only.

TRANSCRIPT:
{transcript_text}

CALLER: Name: {caller_name or 'Unknown'} | Number: {caller_number}

Return exactly this JSON structure:
{{
  "caller_name": "Full name (from contacts or transcript)",
  "caller_relationship": "colleague|friend|family|client|vendor|unknown",
  "purpose": "One sentence: why they called",
  "summary": "2-3 sentences covering the entire call with all key details",
  "key_details": ["specific fact 1", "specific fact 2"],
  "urgency": "low|medium|high|urgent",
  "call_type": "spam|event|routine|important|urgent",
  "action_needed": "Specific action for owner. Example: Call Priya about 3pm deadline.",
  "recommended_response": "What AI should say if calling back. Empty string if none.",
  "deadline": "Any mentioned deadline in natural language, or empty string",
  "should_call_back": true or false
}}"""
