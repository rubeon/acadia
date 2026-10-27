#!/usr/bin/env python3
"""Generate the title screen's text (src/title_text.asm).

The title screen has a mode 7 name (20 characters) and mode 2 lines
(40 characters each).  Screen text modes have exact column counts and
hand-counted strings are off by one constantly, so the strings are
centred and padded here and the widths are checked.

    python3 -I tools/gen-title.py     # writes src/title_text.asm

Do not edit the output by hand; edit this file and run it again.
"""

import os

# the mode 7 name, and the mode 2 lines: the line number (0-17) and
# the text on it
NAME = "ACADIA"
M2_WIDTH = 40
M2_ROWS = 18

BLOCK = [
    (1, "AN ISLAND-BUILDING GAME FOR ATARI 8-BIT"),
    (3, "BY ERIC WILLIAMS AND CLAUDE"),
    (5, "AFTER UTOPIA (1981) BY MATTEL, INC."),
    (6, "NOT AFFILIATED WITH MATTEL, INC."),
    (8, "ALL GRAPHICS, CODE AND MUSIC ARE NEW."),
    (10, "KEYS 1-9 BUY ITEMS, 0 BOATS"),
    (11, "P PAUSES, H SHOWS THE PRICE LIST"),
    (17, "PRESS START OR FIRE TO BEGIN"),
]


def centre(text, width):
    """The text centred in width characters."""
    if len(text) > width:
        raise ValueError("%r is %d characters, wider than %d"
                         % (text, len(text), width))
    left = (width - len(text)) // 2
    return " " * left + text + " " * (width - len(text) - left)


def main():
    name = centre(NAME, 20)
    lines = [centre(text, M2_WIDTH) for _, text in BLOCK]

    # the checks that matter: the widths, and that every character is
    # in the font (the OS font's upper-case set)
    assert len(name) == 20, len(name)
    for row, text in BLOCK:
        assert 0 <= row < M2_ROWS, row
    for line in lines:
        assert len(line) == M2_WIDTH, (line, len(line))
    for ch in name + "".join(lines):
        assert 32 <= ord(ch) <= 95, ch

    out = []
    out.append("; =====================================================================")
    out.append(";  TITLE_TEXT.ASM -- the title screen's text (generated)")
    out.append(";")
    out.append(";  Written by tools/gen-title.py; do not edit it by hand.")
    out.append(";")
    out.append(";  The name is a mode 7 line of 20 characters; the credits are")
    out.append(";  mode 2 lines of 40 characters, centred by the generator.")
    out.append("; =====================================================================")
    out.append("")
    out.append("; the mode 7 name")
    out.append('TI_NAME .SBYTE "%s"' % name)
    out.append("")
    out.append("; the mode 2 lines: the line number, then the text")
    out.append("TI_LIN  .BYTE " + ",".join(str(row) for row, _ in BLOCK))
    out.append("TI_LO   .BYTE " + ",".join("<TI_T%d" % (i + 1)
                                           for i in range(len(BLOCK))))
    out.append("TI_HI   .BYTE " + ",".join(">TI_T%d" % (i + 1)
                                           for i in range(len(BLOCK))))
    out.append("")
    for i, line in enumerate(lines):
        out.append('TI_T%-2d .SBYTE "%s"' % (i + 1, line))
    out.append("")
    out.append("TI_N    =  %d" % len(BLOCK))

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root, "src", "title_text.asm")
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")
    print("wrote %s (%d mode 2 lines, %d characters each)"
          % (path, len(lines), M2_WIDTH))


if __name__ == "__main__":
    main()
