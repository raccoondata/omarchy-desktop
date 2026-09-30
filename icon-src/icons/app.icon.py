"""app: a plain application window with a title bar and two dots. The fallback for anything without its own icon."""
from iconkit import *

icon(
    rect(3.5, 4.5, 17, 15, rx=2.5),
    path("M3.5 8.5h17"),
    dot(6, 6.5, 0.6),
    dot(8, 6.5, 0.6),
)
