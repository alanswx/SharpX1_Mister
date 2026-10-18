# Raw X1 2D media through the D88 mount

October 18, 2026. User direction: keep one OSD entry per drive and select
the image format from the file extension MiSTer reports, instead of the
closed-source core's separate D88/2D/DSK menus
(`docs/OTHER_X1_CORE_COMPARISON.md`).

## Host contract

`CONF_STR` has `S0,D882D ,Drive A;` and `S1,D882D ,Drive B;`. Before every
generic `S` mount (OSD, MGL `type="s"` and saved-config auto-mount), Main
calls `user_io_set_index(user_io_ext_idx(path, ext) << 6 | ...)`
(`../Main_MiSTer/menu.cpp`, `user_io.cpp`, inspected locally).
`user_io_ext_idx` compares three-character fields case-insensitively, with
two-letter extensions space-padded, so `.D88` reports 0 and `.2D` reports 1.
An unlisted extension reports 0, and the strict D88 scan then rejects it.
`sharpx1.sv` latches `ioctl_index[7:6] == 1` per drive on that drive's
`img_mounted` pulse.

## Machine and controller

- `RAW_2D_MEDIA` (machine parameter, default 0) enables the path. The MiSTer
  wrapper sets it for every board revision; the non-savable `turbo-x3-single`
  runner sets it. Ordinary savable runners leave it off and refuse the raw
  runner flags, so their v17 state and warnings are unchanged
  (`test-machine-fdc-default-state`, `test-fdc-default-state` pass).
- `x1_disk_media` returns the active drive's raw flag together with its size.
  The FDC samples both when the mount/selection rescan begins.
- `wd1793` (`RAW_2D=1`): a raw mount of exactly 327,680 bytes fills the same
  sector index a D88 scan builds. It writes 1,280 entries, 40 cylinders x 2
  sides x 16 sectors, N=1 (256 bytes), C = cylinder and H = side, at file
  offset ((C*2+H)*16+R-1)*256, with 16 sectors per track. No header is read.
  A wrong-size raw image stays not-ready. Raw writes skip the strict-D88
  header update, which would otherwise land in the previous sector's last
  bytes. Deleted-data marks and CRC-error status cannot be stored in raw
  media.
- Invalid D88 media still never falls back to raw geometry. Raw is only
  selected by the host's extension.

## Simulation (`make -C verilator test-raw-2d`, `test-raw-2d-mutant`)

Original generated raw image (every byte depends on C/H/R/offset) in drive
A and a D88 in drive B, on the X3 single-clock runner, real Z80/FDC/SD path:

- Reads C/H/R 0/0/1, 0/1/16, 17/0/5, 17/1/3, 39/0/9, 39/1/16 byte-exactly.
- D88 drive B reads correctly in the same run (mixed formats, two drives).
- R=17 returns record-not-found.
- Protected run: the write reports write-protect and nothing is written.
- Writable run: writing 17/1/3 changes exactly those 256 bytes of the output
  copy; the readback of R=2/3/4 matches; originals are unchanged.
- The same raw file without the raw flag is refused as D88.
- Two cold repeats are identical.
- Matched mutation: a copied tree whose raw writes keep the D88 header RMW
  fails at the raw-write oracle ("raw write must change only its own
  sector").

The full `make test`, `test-x3-single`, FDC strict timing/legacy, capacity
class and address-width suites pass after the change.

## Real media cross-check

The `Galaga.2d` copy used on the closed-source core (SHA-256 `75dc785e…`,
327,680 bytes) is byte-identical to the local `Galaga.d88` (`d0cdeb82…`;
16 x 256-byte sectors on all 80 tracks, C/H matching the track table)
converted in exactly the implemented cylinder, side, sector order. All
1,280 raw sectors sit at their computed positions. This independent dump
confirms the geometry rather than relying only on our own generator.

On the fast X3 single runner (non-timing build, 480,000,000 reference
cycles = 15 s, native Turbo IPL `21289570…` + ANK16 `e356dd19…`), raw
`Galaga.2d` and `Galaga.d88` both reach the Galaga title screen (929 vs 928
frames, zero writes). The final frames differ in 6 of 64,000 pixels, all in
column x=1 (rows 22–136), consistent with the one-frame phase offset from the
D88 header scan. Evidence: `output_files/RAW2D_SIM_20261018/` (ignored).

## Open

Board build and MiSTer OSD/MGL mount, native 2D software boot from raw media,
DSK (CPC-style EDSK), 2DD/2HD raw sizes, raw media in snapshots, and
deleted/CRC semantics on raw media.
