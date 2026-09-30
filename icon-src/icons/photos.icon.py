"""photos: Google Photos: a pinwheel of four half-disc petals.
Generated: four spokes at 90 degrees, each closed by a half-disc arc."""
from iconkit import *

icon(
    path("".join(f"M12 12L{pt(polar(7.8, turn))}A3.9 3.9 0 0 0 12 12Z" for turn in (0, 90, 180, 270))),
)
