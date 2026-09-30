"""claude: Claude's burst: 11 rays of uneven length from the centre, nudged off even spacing like the real mark.
Generated: the rays' lengths and angle nudges below."""
from iconkit import *

LENGTHS = [9.0, 6.9, 8.2, 7.4, 8.8, 6.6, 8.5, 7.1, 8.9, 6.8, 7.9]
JITTER = [0, 5, -3, 4, -2, 6, -4, 3, -1, 5, -3]  # degrees off even spacing

icon(
    path(rays(LENGTHS, jitter=JITTER)),
)
