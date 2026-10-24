# Acadia — decisions log

Settled decisions. Add new ones at the end with the next number. To
change one, add a new entry that supersedes it; don't edit history.

| # | Date | Decision | Why |
|---|---|---|---|
| D1 | 2026-10-24 | Target Atari 800XL (64K); keep 48K 800/XE compatible. XEX first, ATR later. | Main test machines: atari800, MiSTer, real 800XL. |
| D2 | 2026-10-24 | Assembler is ATasm; source stays MAC/65 compatible. Only ATasm-ism allowed: `.INCLUDE "file"`. | Owner's toolchain; keeps the source usable on real-machine MAC/65. |
| D3 | 2026-10-24 | Rules and numbers follow the Intellivision original (from a disassembly kept outside the repo). | The disassembly is the only authoritative source available. |
| D4 | 2026-10-24 | No Mattel ROM, disassembly, art or sound in the repo. | Public repo; copyright. |
| D5 | 2026-10-24 | Menus and item selection on the keyboard. | "This is a computer after all" — owner. |
| D6 | 2026-10-24 | Game code calls no OS ROM routines; hardware access is isolated in the platform layer. | Planned Atari 5200 port. |
| D7 | 2026-10-24 | 5200 port will explore keypad and second fire button for item selection and modes. | Owner request; keypad mirrors the original's controls. |
| D8 | 2026-10-24 | Add a 1-player mode against a CPU governor. | Owner goal. |
| D9 | 2026-10-24 | Mixed ANTIC modes: mode 2 status bar, multicolour character map, split by DLI. | Owner goal; proven in M0 test. |
| D10 | 2026-10-24 | POKEY sound and music, all newly composed. | Owner goal; D4. |
| D11 | 2026-10-24 | Original overflow bugs (earned gold > 255, crops + boats > 65) are fixed. | No gameplay value in reproducing them. |
| D12 | 2026-10-24 | Map uses ANTIC **mode 5**: one island square = 2 × 1 characters (8 × 16 scan lines), 20 squares × 11 rows under a 2-line mode 2 status bar. Closes Q1. | Matches the original's 160 × 96 tall-pixel grid one-to-one; ~64 square graphics per font instead of ~32; half the screen memory and update work. |
