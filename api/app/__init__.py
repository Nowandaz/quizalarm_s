"""The BrainWake API: the only place that talks to AI providers.

The app sends a signed-in user's request here; this server checks who is
asking, enforces the daily limit, picks the next AI provider in turn and
returns the result. No AI key ever reaches a phone.
"""
