"""printer: Print settings (CUPS): a printer with a paper tray and a sheet coming out."""
from iconkit import *

icon(
    path("M7 8V3.5h10V8"),
    path("M7 17H5a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"),
    rect(7, 13.5, 10, 7, rx=1),
    dot(17.3, 10.8, 0.9),
)
