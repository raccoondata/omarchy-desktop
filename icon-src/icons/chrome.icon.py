"""chrome: Chrome / Chromium: a ring and hub with three spokes at 120 degrees.
Generated: each spoke leaves the hub tangentially and meets the ring; the
other two are the first turned 120 and 240 degrees."""
from iconkit import *
import math

R, r = 8.5, 3.2
spoke = [(12, 12 - r), (12 + math.sqrt(R * R - r * r), 12 - r)]

icon(
    circle(12, 12, R),
    circle(12, 12, r),
    path("".join(poly(rotate(spoke, turn), closed=False) for turn in (0, 120, 240))),
)
