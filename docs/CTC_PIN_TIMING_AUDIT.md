# CTC terminal-clock phase audit

October 9, 2026. Primary-source timing research, not an implemented native
waveform or completed SIO integration gate.

## Evidence actually inspected

- Existing local Zilog 1982/83 Data Book, SHA-256
  `f95c54fc8ff0e5524434132340e644b94ae7dc9ad861b0976114b6ba8a37bf84`,
  [publisher scan](https://bitsavers.trailing-edge.com/components/zilog/_dataBooks/1982_Zilog_Data_Book.pdf).
  PDF page 98 / printed 87, Figure 12 and counter/timer prose; PDF pages
  101–102 / printed 90–91, AC waveform and numbered parameter table were
  rendered locally and visually read. Page 100 / printed 89 DC table was
  also viewed while locating the AC table.
- Newly retrieved [official Zilog PS018101-0602](https://www.zilog.com/docs/z80/ps0181.pdf),
  retained locally/ignored as `references/manuals/Zilog_CTC_PS018101_0602.pdf`,
  SHA-256 `9bbcaf795f54a4dc0d1ce9e51e9b6c83ed735eb5d56427454bf3b261a7160b11`.
  PDF page 12 / printed 94 was visually read: parameters 28/29 explicitly
  distinguish output rise from output fall. PDF page 8 / printed 90 IRQ/RETI
  page was viewed while locating the table; the whole document was not audited.

The newer CMOS sheet corroborates edge polarity, not interchangeability of
its full electrical behavior with the Sharp LH0082A NMOS device. Use the
older Z80A values for the original board contract.

## Confirmed correction

| Parameter | Triggering clock edge | Output transition | Older Z80A maximum delay |
|---|---|---|---:|
| 28 | Rising | ZC/TO rises | 190 ns |
| 29 | Falling | ZC/TO falls | 190 ns |

These are maximum propagation delays, **not** fixed simulation delays or
an output-width specification. Text extraction loses arrow direction; the
actual scanned table makes the distinction explicit. Do not infer exact
pulse duration from the apparent scale of the schematic timing drawings.
The inspected sources establish edge polarity, but which falling edge ends
each pulse and exact width still require stronger device evidence.

The existing `x1_ctc.sv` deliberately exposes a one-master-edge **event**.
Its timer terminal event is generated after a device CE; its counter path
currently decrements on a synchronized system-clock trigger edge rather than
the primary chip's described subsequent device-clock sampling. Neither is
a full pin model. The [CZ-851 route tests](SIO_MACHINE_WIRING_AUDIT.md) remain
valid bounded event-transport tests, not native ZC waveform acceptance.

## Rejected prototype and test-coverage lesson

A local, uncommitted timer adapter held the event high until the next rising
device CE. Its own width/reset fixtures and 72 event/pulse coupled CTC/SIO
profiles passed in `/tmp/x1-ctc-timer-pulse.log` and
`/tmp/x1-ctc-pulse-coupled.log`. Those tests checked that chosen policy, not
the manufacturer's falling-edge contract. Once parameter 29 was visually
read, the prototype, its test target and temporary CI selection were removed.
**It is not implemented, qualified, selected by CI or part of the machine.**
The ignored build/log outputs are retained for diagnostic recovery; no user
or private files were removed. Existing CTC/SIO source was restored precisely
to the committed checkpoint. A passing functional serial byte alone does
not establish pin phase or pulse width.
The retained selector/edge/CTC routing recipe was rerun after removal and
terminates zero, 48 PASS messages in `/tmp/x1-ctc-phase-retained-routes.log`.

## Required implementation and acceptance

1. Resolve pulse duration/which falling edge and device-clock phase against
   original device evidence or a physical CTC capture. Preserve the CZ-851
   inversion of CPU clock rather than assuming CTC and SIO CE coincide.
2. Expose independent rising/falling device-phase enables from `clk_sys`;
   no FPGA logic is to be clocked by CTC output or an internally divided net.
   Include compensated single-clock frequencies and phase/reset determinism.
3. Keep the existing event interface for IRQ/trigger compatibility until
   qualified. Add a distinct opt-in level interface, with timer and counter
   behavior, trigger sampling, stopped clocks, soft/global resets and overlapping
   terminal events covered independently of the serial engine.
4. Test RX-rising versus TX-falling delivery, captured RX data, selector changes,
   A/B independence, actual CPU baud programming, modem/IRQ/reset combinations
   and waveform timestamps. Negative controls must reject an immediate
   one-master pulse **and** the rejected next-rising-CE waveform.
5. Then source-bound shared-machine decode/daisy/snapshots, fit and hardware
   acceptance. CZ-880 routing remains a separate model gate; do not substitute
   an arbitrary fixed baud generator or declare full Turbo/Z support.

No machine RTL, snapshot version, asset or RBF is changed by this audit.
