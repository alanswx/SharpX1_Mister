# Shanghai v11 qualification and timed-replay diagnosis

October 5, 2026. **The unchanged release-bound cursor/pair-removal test now
passes on v11**, using native joystick cursor feedback to prepare the same
historical pair. No RTL, ROM/game/RAM bytes, snapshot format or removal
assertion was changed to obtain this result.

Together with completed v11 Xevious, Druaga, Mappy and Galaga movement/fire
checks, this gives **five commercial titles with bounded native gameplay
evidence** on the frozen baseline machine. It is not full compatibility,
Turbo gameplay, level completion or FPGA/hardware acceptance.

## What failed and what changed

The original fixed-duration replay is preserved under
`verilator/obj_dir_v11_fast/native-requalification/shanghai/` and still fails.
Read-only RAM comparison against the historical v04 run finds the expected
two type-11 tiles still present at `3E1B/3EBA`, but cursor positions diverge:

| Stage | Historical v04 | Original v11 replay |
|---|---|---|
| Cursor checkpoint | (488,167), zero selected | Same |
| First target | (56,18), one selected, tile `91` | (88,18), zero selected, tile `11` |
| Second target | (152,128), two selected | (184,128), only one selected |

The fixed pulse sequence therefore missed its intended positions; this
explains the observed preparation failure, not the underlying cause of
polling-phase differences. No CPU/FDC timing-correctness claim follows.
Do not relax the historical assertion or turn the old failure into a pass.

New `verilator/tests/prepare_shanghai_pair.py` observes cursor coordinates
from normal RAM dumps and advances the authentic state in 20 ms joystick
segments, with explicit bounds/overshoot/watchdog assertions. It targets
exactly (56,18) then (152,128), requires the same selected tile bytes/counts,
and invokes **unchanged** `test_shanghai_gameplay.py`. This is normal input
control, not injected or restored dump RAM. Source assets/states/executable
are hashed before and after. The original failure directory is untouched.

`requalify_commercial.py` now defaults Shanghai to this feedback preparation;
`--shanghai-preparation historical` retains the old timed replay. Preparation
mode is recorded and mismatching resumes are rejected. Asset-free scheduling
tests verify the routes and single output argument; those mocks are not
gameplay evidence. Use a fresh output directory to preserve previous trials.

## Executed result and identity

Active machine source **`95c181c`**, snapshot **v11**, base Turbo/DMA/X3/single
disabled, SYS **32,000,000 Hz**, VID **28,571,428 Hz**, fast no-timing model.
Fresh native boot used the unchanged IPL and disk, not an older state. The
feedback trial has **131 native continuations**, followed by original
300 ms neutral/right/repeat and click/release/removal-repeat checks.

| Asset / result | SHA-256 or value |
|---|---|
| Frozen executable | `ee270b8052a350528c0d16f69da119a4576769ad0fa026ae9b4bd29b8d9507c7` |
| Shanghai disk | `648d150e8e36b5ba282bb7e3475e704f5f938d5c4a77ef6d7d000908f48513dc` |
| Fresh native cursor state | `0bdb71f732b6c19aeab457ca91e8045f5a0ab0bed0112e2613a966bd5fcd38d5` |
| Feedback-prepared pair state | `149b8def69986234e34ba23f8b2c075985261b3ea8b2bec001957f12c8e9cd85` |
| Cursor idle → right | (488,167) → (544,160) |
| Selected before / after removal | 2 / 0 |
| Tile bytes before / after | `91,91` / `00,00` |
| Removed counter | 0 → 2 |
| Idle / removed RGB frame hashes | `f80f4af748047b39` / `44ed23bc5976312c` |

Full RAM/text/attribute/sub-RAM/CPU/RGB/state/report repeats and unchanged
source hashes pass. No keyboard bytes, new downloads or disk accesses occur
in the control trials. Private provenance and actual frames are under
`verilator/obj_dir_v11_fast/shanghai-feedback/`; terminal log is
`/tmp/x1-v11-shanghai-feedback.log`. Actual rendered PNG locally:
`/private/tmp/x1-v11-shanghai-pair-removed.png` (not an AI-created image).
Media/states remain ignored; no binary redistribution grant is assumed.

Remaining: explain polling-phase differences, broader native reset/disk
continuity, delay-aware gameplay and physical MiSTer acceptance. Arcus and
Bastard Special gameplay remain open independent Turbo/software gates.
