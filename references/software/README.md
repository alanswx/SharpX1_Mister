# Sharp X1 test software

Retrieved 2026-10-02 from the authors' GitHub repositories. These are homebrew
programs, not commercial software collections. Only this directory was changed.
No program was built, executed in an emulator, booted on the active
`rtl/sharpx1.v` machine, synthesized, or tested on hardware during acquisition.
The source and media checks below establish provenance and structure, not
correct execution. No additional MAME checkout was downloaded or used.

## Obtained media

| Local path, relative to this directory | Kind | Intended target | Load / entry | Best use |
| --- | --- | --- | --- | --- |
| `private-downloads/cross-chase/Xchase_x1.d88` | Native bootable 2D floppy game | Base X1 | `0000 / 0000` | First game after disk boot, text, keyboard and PSG work |
| `x1sgl-balls/project/x1balls.d88` | Native bootable 2D floppy sprite stress demo | X1 Turbo; base compatibility unverified | `0000 / 0000` | Graphics planes, masking, double buffering, keyboard interrupts |
| `x1t-crtc-vscroll/project/x1t_crtcv_2d.d88` | Sparse 2D floppy timing demo | X1 Turbo, 15 kHz display | `6000 / 6000` | Later CRTC/CTC timing and smooth scroll checks |
| `x1t-crtc-vscroll/project/x1t_crtcv_2hd.d88` | Sparse 2HD floppy timing demo | X1 Turbo, 15 kHz display | `6000 / 6000` | Same demo through the alternative disk layout |
| `x1t-crtc-vscroll/project/x1t_crtcv.bin` | Four-byte LOADM header + Z80 machine code | X1 Turbo | Header `6000`, end `63FA`; entry `6000` | Direct RAM-loader candidate, bypassing disk transport |

The scroll `.bin` is **not** a raw ROM or tape image. Its initial four bytes are
`00 60 FA 63`, followed by `C3 03 60` (a jump to `6003`). For a direct RAM loader,
skip the four-byte header, copy the following 1,018 bytes to `6000..63F9`, and
start at `6000`. Set up a valid caller return address if using its exit button:
the program restores SP/I and returns. This loading route is inferred from the
binary and source and has not been exercised here. No `.tap` was acquired.

## X1SGL Balls — MIT, redistributable with its notice

Author: X1turbo.Agency; copyright 2019. Pinned source revision:
`db9ac70441dfbe34a1a56bef9e26682d1fb850aa`.

- [Author project and instructions](https://github.com/X1turboAgency/x1sgl_balls).
- [Explicit MIT permission notice](https://github.com/X1turboAgency/x1sgl_balls/blob/db9ac70441dfbe34a1a56bef9e26682d1fb850aa/LICENSE.txt), also preserved in `x1sgl-balls/LICENSE.txt`.
- [Direct disk image](https://raw.githubusercontent.com/X1turboAgency/x1sgl_balls/db9ac70441dfbe34a1a56bef9e26682d1fb850aa/project/x1balls.d88).
- [Exact source archive downloaded](https://codeload.github.com/X1turboAgency/x1sgl_balls/tar.gz/db9ac70441dfbe34a1a56bef9e26682d1fb850aa).

The notice explicitly grants use, copying, modification, publication,
distribution and sale, conditional on preserving the copyright and permission
notice. Keep the local LICENSE.txt alongside copied binaries. Original source
notices were preserved. The extracted tree includes the author's README,
assembly, sprite resources and build scripts. The complete upstream archive
is also retained; no included Windows executable was run.

Controls: `1`, `2`, `3` add a ball rendered with one, two or three graphics
planes; `4` removes one; Space cycles 60/30/20 FPS. The display reports ball
count, FPS and `Dropout` when rendering overruns the frame. These descriptions
come from the author's README, not observations on this core.

Loading: insert `project/x1balls.d88` in drive 0 and boot through a legally
obtained X1/Turbo IPL and a working floppy path. The first sector's system
record has type `01`, name `X1Balls`, extension `Sys`, payload size 19,748,
load/entry `0000`, and start sector field `0001` at header offsets 30–31.
`project/src/boot_data.asm` independently sets the origin to `0000`.
This is native machine code; no Hu-BASIC or disk OS image is supplied or required
by the source. A working IPL and character generator remain platform assets.

Dependencies visible in the source include writable low RAM after IPL handoff,
text/attribute VRAM, planar graphics I/O, palette, CRTC, VSYNC status on PPI
port `1A01`, the sub-CPU protocol at `1900`/`1A01`, and Z80 IM2 keyboard
interrupts. It sends sub-CPU command `E4` and vector `10`, with the vector table
at `F500`. Code also writes Turbo screen/VRAM control port `1FD0`; therefore
the author's broader X1 library description does not establish that this exact
disk is a base-X1 acceptance test. RAM work areas extend through `FFFF`.

Rebuilding requires the author's specified Windows batch environment and
紅茶羊羹's `z80as.exe`, which is not bundled, plus the media/resource tools in
the archive. A different assembler may need syntax adjustments. The supplied
disk can be used without rebuilding. No assembler was installed here.

## CRTC vertical scroll — MIT, hardware-sensitive Turbo test

Author: X1turbo.Agency; copyright 2021. Pinned source revision:
`fae694cac24c6de7b8364d535d4f74be7b915120`.

- [Author project and instructions](https://github.com/X1turboAgency/x1t_crtc_vscroll).
- [Explicit MIT permission notice](https://github.com/X1turboAgency/x1t_crtc_vscroll/blob/fae694cac24c6de7b8364d535d4f74be7b915120/LICENSE.txt), preserved in `x1t-crtc-vscroll/LICENSE.txt`.
- [Direct 2D disk](https://raw.githubusercontent.com/X1turboAgency/x1t_crtc_vscroll/fae694cac24c6de7b8364d535d4f74be7b915120/project/x1t_crtcv_2d.d88).
- [Direct 2HD disk](https://raw.githubusercontent.com/X1turboAgency/x1t_crtc_vscroll/fae694cac24c6de7b8364d535d4f74be7b915120/project/x1t_crtcv_2hd.d88).
- [Direct headered binary](https://raw.githubusercontent.com/X1turboAgency/x1t_crtc_vscroll/fae694cac24c6de7b8364d535d4f74be7b915120/project/x1t_crtcv.bin).
- [Exact source archive downloaded](https://codeload.github.com/X1turboAgency/x1t_crtc_vscroll/tar.gz/fae694cac24c6de7b8364d535d4f74be7b915120).

The MIT grant has the same notice-preservation requirement as Balls. Source,
build scripts, README and notice are extracted locally; the complete upstream
archive is retained. Rebuild requirements match the Windows/z80as workflow
above. Neither rebuild nor included host tools were executed.

The author reports operation on X1turboZIII and X1turboII with a 15 kHz-capable
display, and explicitly says the files do not run correctly in emulators and
should be run on real hardware. This warning makes the demo useful for later
hardware timing comparison, but unsuitable as the initial emulator-derived
golden regression. The repository includes its own synthetic text sample;
mentioning Ys II as inspiration does not make this a copy of that game.

Loading: drive 0 + IPL, or the direct RAM route above. Both system records
specify payload size 1,018 and load/entry `6000`. Both D88 files populate only
the first track: the 2D image has 16 sectors and the 2HD image 26 sectors, each
256 bytes. They are sparse images, not complete disk dumps; a disk adapter must
handle absent track entries. Do not pad or normalize them silently.

The scrolling runs automatically at one-quarter dot per VSYNC. Source
`project/src/main.asm` exits on joystick 1 trigger 2/B (bit 6); the input source
reads PSG registers 14/15 via ports `1C00`/`1B00`. A usable exit therefore
needs joystick/PSG I/O. It uses IM2, the CTC at `1FA0`, precise VSYNC timing,
CRTC register writes, Turbo port `1FD0`, VRAM and a character generator.
No proprietary BASIC or separate application OS is used. The direct binary
does not by itself provide those devices or establish a boot.

## CROSS Chase — acquired for local non-commercial tests only

Author: Fabrizio Caruso. Exact release tag `XChase`, source commit
`3dff185107a20a92ad1b2ddada8dba6154ceb4bb`.

- [Author release](https://github.com/Fabrizio-Caruso/CROSS-LIB/releases/tag/XChase).
- [Direct game disk downloaded](https://github.com/Fabrizio-Caruso/CROSS-LIB/releases/download/XChase/Xchase_x1.d88).
- [Release-specific license section](https://github.com/Fabrizio-Caruso/CROSS-LIB/blob/3dff185107a20a92ad1b2ddada8dba6154ceb4bb/README.md#licence), preserved in `private-downloads/cross-chase/upstream-README.md`.
- [Game source with the same notice](https://github.com/Fabrizio-Caruso/CROSS-LIB/blob/3dff185107a20a92ad1b2ddada8dba6154ceb4bb/src/games/chase/main.c).
- [Exact X1 build recipe](https://github.com/Fabrizio-Caruso/CROSS-LIB/blob/3dff185107a20a92ad1b2ddada8dba6154ceb4bb/src/makefiles.chase/makefiles_z88dk/Makefile_z88dk_q-z#L950).
- [Exact input mappings](https://github.com/Fabrizio-Caruso/CROSS-LIB/blob/3dff185107a20a92ad1b2ddada8dba6154ceb4bb/src/cross_lib/input/input_target_settings.h).

The author's grant permits non-commercial use, requires honest attribution
and marking altered sources, and prohibits removing its notice from source
distributions. It does **not** explicitly grant redistribution. This is not
an unrestricted open-source license and public download availability is not
redistribution permission. The disk and README are consequently under the
locally ignored `private-downloads/` directory. Do not add them to commits,
release packages, or mirrors without an explicit author grant covering binary
redistribution and the intended use. No permission request was sent.

The X1 recipe uses z88dk `+x1`, `-lndos`, native conio, PSG sound, and no BASIC
or application OS dependency. It does not enable the joystick input define;
the release source maps lowercase `i/k/j/l` to up/down/left/right and Space to
fire. Native IPL/D88 boot, start prompts, real PS/2 movement and actual RGB
gameplay are now verified in the shared core. The startup script sends F,
Space at successive prompts, and Caps Lock to disable the firmware's default
uppercase mode. See [playing and regression evidence](../../docs/PLAYING.md).

Additional authored source was downloaded and inspected at pinned commit
`3dff185107a20a92ad1b2ddada8dba6154ceb4bb` of
[CROSS-LIB](https://github.com/Fabrizio-Caruso/CROSS-LIB/tree/3dff185107a20a92ad1b2ddada8dba6154ceb4bb):
`src/games/chase/{main.c,character.h,init_images.h,variables.h}` and
`src/cross_lib/input/input_target_settings.h`. These ignored local files
retain their author's notices. Source inspection and binary disassembly
identify the player's x/y/status structure at RAM 35C0–35C2 and cyan `*`
glyph, used by the release-specific regression; no upstream source was changed.

Insert the D88 in drive 0 and boot via a legally obtained base-X1 IPL.
The system record specifies 14,024 bytes, load/entry `0000`, and start sector
field `0020` at offsets 30–31. An instrumented RAM-injection route would first
need correct extraction of that payload and initialization of the runtime's
RAM/interrupt environment; treating the entire D88 as a raw binary is invalid.
Dependencies include disk/FDC loading, ROM handoff to RAM, text/attribute
display and font, sub-CPU keyboard input, and AY PSG for sound. Use it after
those paths work; it does not isolate the current bus/ROM-loader repairs.

For a freely redistributable **game** fixture, obtain the author's explicit
binary redistribution permission or select/build another permissively licensed
game. A closest source-build option found is
[H.O SOFT's SLANG compiler](https://github.com/h-o-soft/SLANG-compiler), whose
[license](https://github.com/h-o-soft/SLANG-compiler/blob/main/LICENSE) includes
MIT compiler/runtime components and whose `x1native` target supports native
auto-boot cassette output without S-OS/LSX/BASIC. That repository was inspected
online only: no compiler, sample game, or tape from it was downloaded or built.
Next requirements are an explicitly licensed sample, review of its linked
runtime/assets, compiler build prerequisites, and emission/validation of an
X1 tape or machine-code payload. It is a candidate, not an obtained fixture.

## SHA256 and structural checks

Paths below are relative to this directory. Hashes cover original downloaded
archives/media and the saved restrictive notice. Extracted upstream source and
licenses can be checked against the pinned archives.

```text
ff0c7130591f2f51ee08002b7771b3fa3f15a1754ef1cbb663c47ecc171d8419  x1sgl-balls/upstream.tar.gz
54fc0d1891f922d425d6be1ada5d5d28c6dc3c2e063f86756b36c6f7510ba7eb  x1sgl-balls/project/x1balls.d88
53e0208cbdc21f422d6e84e75641e3141810cbd020c6ffb5287e2cf4fe229d8b  x1t-crtc-vscroll/upstream.tar.gz
8b4c91bdb9fbd70ca3002e9b942fab3a90c1db8d21b9151535a6da258d325893  x1t-crtc-vscroll/project/x1t_crtcv.bin
80f7947a0545df059e03d1f0885e6b1c52646e853580de895ad0e35c2f8f8ce0  x1t-crtc-vscroll/project/x1t_crtcv_2d.d88
c1270a0cf212cb78dc5fb1d708e5658e2bc4697664964692fb1d032ed23406ce  x1t-crtc-vscroll/project/x1t_crtcv_2hd.d88
2fb70389737a7d54bff5a746b581343385ebde115cefb77ded32c473dcde97ec  private-downloads/cross-chase/Xchase_x1.d88
fd2321db17465665df337facb2bff26a7003a5430343515c30203f71729e1667  private-downloads/cross-chase/upstream-README.md
fcabb7c7942eba7715e561dd537746a0b6109565b55bad830e8128625862a48d  private-downloads/cross-chase/main.c
d056fc542906575ea99475a6d2c7db6a729a0be1d54c5f87ea5ca7c61980d03d  private-downloads/cross-chase/input_target_settings.h
3ce93ba017bf72c0571a1566d27a3286ccc21b503e74afb577ec326397ebed92  private-downloads/cross-chase/character.h
f3a235f61d917714fb01a998b5e8afb3edbb95d6a8124b5957ed900895f4eb1e  private-downloads/cross-chase/init_images.h
ac85acc5aa633b39bb4559cf41e53e523bdb59b739286350da8f9bfd6a7d2690  private-downloads/cross-chase/variables.h
```

All four D88 files were parsed locally: declared disk sizes match actual sizes;
populated track entries and their sector headers/payload bounds are valid.
Balls and CROSS Chase each contain 80 track entries / 1,280 sectors, 348,848
bytes total. The scroll 2D/2HD files are 5,040 / 7,760 bytes. The headered scroll
binary is 1,022 bytes and its payload length matches both disk boot records.
These structural checks alone did not execute Z80 instructions or certify
the floppy adapter. The subsequent CROSS Chase runtime verification is
recorded separately above; Balls and the Turbo scroll fixture remain unexecuted.

When running later tests, record active machine path/configuration, asset hash,
CPU/system/video clocks, reset sequence, duration and observed bus/frame/audio
evidence. Keep direct RAM execution distinct from IPL/media boot. This software
acquisition alone does not complete any machine bring-up TODO.
