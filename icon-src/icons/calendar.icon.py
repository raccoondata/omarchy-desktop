"""calendar: a calendar page with binder rings and a row of day dots. HEY Calendar and others."""
from iconkit import *

icon(
    rect(3.5, 5, 17, 15, rx=2.5),
    path("M3.5 9.5h17M8 3v4M16 3v4"),
    dot(8.3, 14, 0.95),
    dot(12, 14, 0.95),
    dot(15.7, 14, 0.95),
)
