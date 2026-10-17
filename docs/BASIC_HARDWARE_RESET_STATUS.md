# Native HuBASIC commands and Main reset on MiSTer

October 15 local / October 16 UTC: the existing fd9a0850 external-font RBF
boots SHARP-HuBASIC CZ-8FB01 V1.0 through the native Turbo IPL and passes
bounded arithmetic, stored-program and both Main reset paths. Seven fresh
mrext PNGs match **148,480 exact banner/transcript pixels**. This is functional
hardware evidence on a build whose physical timing still fails.

## Configuration and evidence

- MiSTer: `mister14` / `10.0.2.14`; the previous owned X1OSD06 test was checked
  before loading a unique RBF/config/media/MGL. Other installed cores,
  configurations and original media are preserved.
- RBF SHA: `fd9a085061a5fa5f6cc3c929a37f5b266d2391b5dd1b14752f3d8f794db83692`.
  All **428 compiler inputs** match the earlier source-bound build.
- Native 32-KiB Turbo IPL SHA:
  `212895703175665be8544daa55b65da1aebcf1e9a2db65bcc1622e564b802b71`.
  ANK16 is the existing user file, separately hashed in the deployment.
- HuBASIC D88 SHA:
  `ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a`.
  Only a disposable copy is mounted, with independent zero-status write
  protection. File hashes establish unchanged payloads; FAT mode bits alone
  are not a write-protection proof.
- A complete synthetic physical font is required before this experimental
  profile releases its CPU, even for ANK-only software. Its 256-KiB DDR hash
  is `d18c7cb9c91d05b3d70e9061ce0ef36d2976960e1bb74984f3ef85fd17d7032b`.
  BASIC uses the built-in ANK8; no native Kanji is qualified.
- SYS is configured at 32 MHz; fitted VID is 42.954545 MHz. These are not
  physical clock measurements. The existing fit still fails setup/recovery/
  hold; no new Quartus flow or RTL change was made here.

Deployment: `output_files/X1HW_20261016T000959Z_fd9a0850/`.
Accepted matrix: its `BASICRESET_20261016T001300Z/manifest.json`, driver
`scripts/mister_basic_reset.py`, terminal session `4896` (exit zero), log
`/tmp/x1-basic-hardware-gate.log`. The driver, oracle helpers and FPGA font
source were copied/hashed before input. [Actual native screenshots](../output_files/X1HW_20261016T000959Z_fd9a0850/BASICRESET_20261016T001300Z/screenshots.html).
It records all 75 key actions and
actual mrext screenshot records. The installed Main binary hash is checked;
local Main navigation references are not claimed as its build provenance.

## Native checks

| Phase | Required visible behavior |
| --- | --- |
| No Enter | Typed expression fails the unchanged arithmetic completion oracle |
| Arithmetic | `PRINT 6*7`, separate ` 42`, then `Ok` |
| Menu without selection | F12/Up/Up/F12 preserves the arithmetic; new-result oracle rejects |
| No reset | `PRINT 9*9` appends at row 16, gives ` 81`/`Ok`; reboot placement at row 13 rejects |
| R Reset-and-close | F12/Up/Up/Enter, native reboot, then `PRINT 9*9` gives fresh ` 81`/`Ok` at row 13 |
| T Reset | F12/Up/Up/Up/Enter, then F12 closes OSD; native reboot and `PRINT 8*8` gives fresh ` 64`/`Ok` |
| Stored program | After T reset, `10 PRINT 9`, `LIST`, listed `10 PRINT 9`, `Ok`, `RUN`, separate ` 9`, `Ok` |

The driver performs **no warm RBF load, upload, mount, reset chord or Linux
reboot**. It uses real Main/mrext keys and the guest's native interpreter.
No host RAM injection, state patch or fake execution result is used.
Different post-reset answers prevent an old image from satisfying the next
oracle. No-reset and menu-without-selection controls distinguish reset
causality from simply sending another command.

The unchanged public FPGA ANK source renders every expected RGB component
of complete 80-cell banner/transcript rows, including black padding. All raw
captures are 640x200. No crop, rescale, color tolerance or screenshot rewriting
is used. Echo is uppercase under inherited Caps-on firmware; the
[CSP reference](BASIC_REFERENCE_RESET_STATUS.md) separately pins lowercase
expectations and its own supplied font.

After both resets, RBF, IPL, ANK16, physical font, disk payload, installed Main,
font DDR and compiler/source inputs rehash unchanged. Physical reset edge,
CPU ownership and active FDC/DMA phase are not traced. Raw PNGs contain core
video, not the OSD overlay. Menu identity follows bounded inputs, the unchanged
no-selection control and new native results on the same Main/RBF.

## Preserved attempts and remaining work

The subsequent [metadata startup diagnosis](BASIC_METADATA_STARTUP_STATUS.md)
isolates the base-IPL blank display to this external-font profile's required
third metadata byte. Generated initialization/skip controls establish that
effect on the same RBF; they do not qualify unmodified base IPL or invent a
native power-on Kanji value.

The later [matched IPL/ANK16 collection](BASIC_IPL_MATRIX_STATUS.md) now
repeats all four combinations: Turbo arithmetic succeeds with/without ANK16,
while base 4-KiB uploads stay black. Its two explicit FF-tail controls also
stay black; the Turbo build exposes a 32-KiB IPL aperture. The earlier
confounded setup observations below retain their historical scope.

The first generic base helper omitted index 5, leaving this profile's CPU
paused. Its noisy frame is preserved in `X1HW_20261016T000411Z_fd9a0850`;
this is incomplete setup, not a native failure control. The corrected
base-IPL/synthetic-font trial in `X1BASIC_20261016T000625Z` reaches persistent
blank 640x200 after F and is not accepted. The passing profile additionally
supplies native Turbo IPL and ANK16. This is not an isolated IPL-versus-font
experiment or a diagnosed RTL defect.

`scripts/mister_x1.py deploy` now accepts explicit `--ipl`, `--font16` and
`--physical-font`. It checks exact file sizes without conversion, emits
indices 0/4/5 before mounting the disk and checks remote hashes before loading.
Invalid sizes reject before staging/network use. Existing base-only calls
retain their optional-asset behavior; external-font callers must supply the
complete physical font. Old helper bytes and all attempts remain preserved.

General BASIC compatibility, SAVE/LOAD, representative graphics, other
models/releases, unresolved base-IPL boot, active-device reset, exact WAIT
and physical timing closure remain open. No ROM/font/media redistribution
permission is inferred. The separate historical fixed-FDC RTL warm matrix
timed out before terminal evidence; it remains unaccepted and is preserved
without restarting. This does not change the completed physical gate.
