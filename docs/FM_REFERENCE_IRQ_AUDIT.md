# FM interrupt/reference follow-up

October 9, 2026. Neetan is now shallow-cloned into ignored
`references/emulators/neetan`, revision
`605452881bc725de6cffc7bf70ea5c9a7d783c5d`. Existing local MAME is reused,
not downloaded again. Neetan is inspected statically, **not built/executed**.
Its complete root LICENSE is BSD three-clause; no implementation/assets are
copied into FPGA RTL. This is emulator evidence, not a physical wiring proof.

Primary implementation sources inspected:

- [OPM wrapper](https://github.com/neetandev/neetan/blob/605452881bc725de6cffc7bf70ea5c9a7d783c5d/crates/device/src/soundboard_opm.rs)
  uses a 4 MHz YM2151 input and separate observable IRQ state/edge methods.
- [X1 bus](https://github.com/neetandev/neetan/blob/605452881bc725de6cffc7bf70ea5c9a7d783c5d/crates/machine_x1/src/bus.rs)
  schedules FM timers/status without routing that IRQ to the CPU. Its
  `sync_interrupts` instead uses sound CTC pending state. No calls to the
  wrapper's IRQ-edge/state methods occur in `machine_x1` at this revision.
- [Read ports](https://github.com/neetandev/neetan/blob/605452881bc725de6cffc7bf70ea5c9a7d783c5d/crates/machine_x1/src/bus/io_read.rs)
  return fixed detection zero at 0700, YM status at 0701 and optional-board
  CTC at 0704–0707. Writes use 0700 address/0701 data plus CTC ports.
  Do not copy that detection value into our CZ-880 subset without primary
  hardware evidence: current shared decoder exposes genuine chip status.
- [Interrupt controller](https://github.com/neetandev/neetan/blob/605452881bc725de6cffc7bf70ea5c9a7d783c5d/crates/machine_x1/src/interrupt.rs)
  models sound CTC → SIO → DMA → main CTC → keyboard. Its sound/interrupt
  fixtures were read, not run; source tests are not executed acceptance.

This adds a second inspected implementation agreeing with our provisional
4 MHz input, unlike local MAME's 2 MHz configuration. It does **not** resolve
CZ-880 built-in IRQ routing or optional-board compatibility. Neetan's sound
CTC zero handler does not explicitly cascade channel 0 into 3, unlike the
local MAME board configuration. Its fixed detection port also differs from
the direct status treatment in MAME. Preserve these discrepancies rather
than treating the emulator descriptions as a native truth table.

Re-rendered and visually inspected both original CZ-880 service-manual
sub-board sheets 47/48 at 160 dpi, not just earlier crops. Page 48's partial
YM symbol visibly labels pins 8/9 NC; this supports not inventing CT1/CT2
connections to a CTC on that sub-board. The adjoining scan still does not
give a confidently traceable YM IRQ pin-2 destination. A missing visible
line is not proof of NC. No direct CPU IRQ or synthetic daisy vector is added.
[Original scan](https://eaw.app/Downloads/Manuals/Sharp/CZ-880_Service_Manual.pdf).
PDF SHA-256 `70a5f8da327ed25710e76d60117c4f82a655e6a7b29a34cb3239c75f0bd65a81`.
Local render prefix `/tmp/x1-fm-irq-audit.PLwoAd/sheet-{47,48}.png` is ignored.

| Inspected source | SHA-256 |
|---|---|
| Neetan X1 `bus.rs` | `5defbd1b3b98ece18e3e18cec0499bcb9671667e2b39302b314c4ebcb3d57fd7` |
| `interrupt.rs` | `88c3e2b40d310caf58cf19c518b7257f2a62e81a0674958ff853e220797b0524` |
| `soundboard_opm.rs` | `3b5722cbf4de54e9fffad4ad81a1398b97a7eccc5c5ce0cade76b0164827564f` |

Next native gate: obtain a readable board/net drawing or inspect a physical
CZ-880/CZ-8BS1 separately, distinguish built-in vs optional-board devices,
then qualify exact decode/detection/clock/IRQ pins and CPU ACK/RETI ownership.
Current successful generated audio/status tests and pending FPGA fit do not
complete that gate. No MiSTer or firmware is modified by this audit.
