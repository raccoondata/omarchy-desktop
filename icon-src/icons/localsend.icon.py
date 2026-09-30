"""localsend: LocalSend: a ring of eight dashes around a solid centre.
Generated: eight 24-degree arcs, one every 45 degrees."""
from iconkit import *

icon(
    path("".join(arc(8.3, turn - 12, turn + 12) for turn in range(0, 360, 45))),
    dot(12, 12, 3.6),
)
