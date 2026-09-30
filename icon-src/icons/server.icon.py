"""server: a server: two stacked rack units with status lights."""
from iconkit import *

icon(
    rect(4, 4.5, 16, 6.5, rx=2),
    rect(4, 13, 16, 6.5, rx=2),
    path("M11 7.75h5.5M11 16.25h5.5"),
    dot(7.5, 7.75, 0.95),
    dot(7.5, 16.25, 0.95),
)
