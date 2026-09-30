"""chatgpt: ChatGPT: three capsules crossed at 60 degrees, echoing OpenAI's knot.
Generated: one capsule, turned 0, 60 and 120 degrees (computed, not an SVG
transform)."""
from iconkit import *

icon(
    *(path(capsule(17.4, 6.8, turn)) for turn in (0, 60, 120)),
)
