"""discord: Discord: the game-controller face, with two eyes."""
from iconkit import *

# Drawn 1.7 low and a hair wider than the live area: lifted and scaled to 98%.
FIX = dict(dy=-1.65, scale=0.98)

icon(
    path(adjust("M8.7 7.2c-1.6.3-3 .9-4.3 1.7-1.4 3-1.8 6-1.4 9 1.4 1.1 3 1.8 4.6 2.2l1.1-1.8M15.3 7.2c1.6.3 3 .9 4.3 1.7 1.4 3 1.8 6 1.4 9-1.4 1.1-3 1.8-4.6 2.2l-1.1-1.8M7.6 16.9c2.9 1.3 5.9 1.3 8.8 0M8.6 8.7c2.3-.6 4.5-.6 6.8 0", **FIX)),
    dot(*adjust_pt(9.4, 13.2, **FIX), 1.15),
    dot(*adjust_pt(14.6, 13.2, **FIX), 1.15),
)
