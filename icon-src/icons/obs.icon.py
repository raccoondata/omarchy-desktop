"""obs: OBS Studio: a circle holding three small circles spaced at 120 degrees.
Generated: the small circles sit 4.2 from the centre, 120 degrees apart."""
from iconkit import *

icon(
    circle(12, 12, 8.8),
    *(circle(*polar(4.2, turn), 2.3) for turn in (0, 120, 240)),
)
