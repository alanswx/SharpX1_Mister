"""Synthetic 048 provenance controls, not native STA or pin qualification."""
import hashlib
import pathlib
import sys
import tempfile

ROOT=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from audit_held_sdc_context_probe import audit_sources_048

names=['rtl/x1_hdmi_clock_handoff.sv','sys/sys_top.v',
       'scripts/constraints/hdmi_held_mode_candidate.sdc',
       '../held-context-048d996-v1/hdmi_held_mode_candidate.sdc',
       '../held-context-048d996-v1/hdmi_inactive_data_candidate.sdc',
       '../held-context-048d996-v1/quartus_held_sdc_context_probe.tcl']
paths=names[:3]+['scripts/constraints/hdmi_held_mode_candidate.sdc',
                 'scripts/constraints/hdmi_inactive_data_candidate.sdc',
                 'scripts/quartus_held_sdc_context_probe.tcl']
values=[hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in paths]
values+=['24e81859acbebe38cffd6590c326898f27789413c472f87cf865d12ad7ae5ee2',
         '757466f7a8dcae2b80f81e4c933d04d44b5813de3af55e651252c3fdf32c849d',
         '96220a82666d86e8f3f8b57de6aed3f704fb9d0baf6ac74033167fc2a611c946',
         '6f08e1948e0e6d791e344d01cb170d58f46b9f8dc5ff73cd59e4444016f1b408',
         '16fd053ce22f7ab13f2a2d4982bda07092ede03a7011a5d98a3c3aa16e934a88']
names += [f'output_files/sharpx1_turbo_z_handoff.{ext}' for ext in ('fit.rpt','fit.summary','sta.rpt','sta.summary','rbf')]
lines=[f'{value}  {name}\n' for value,name in zip(values,names)]
with tempfile.TemporaryDirectory(prefix='held-context-048-') as temporary:
    log=pathlib.Path(temporary)/'provenance.log'
    log.write_text(''.join(lines*2));audit_sources_048(log,ROOT)
    mutations=[lines,lines*3,lines+list(reversed(lines))]
    for i in range(11):
        wrong=list(lines);wrong[i]='0'*64+'  '+names[i]+'\n'
        mutations += [wrong*2,lines+wrong]
    mutations.append([line.replace('held-context-048d996-v1','other-fit') for line in lines*2])
    for bad in mutations:
        log.write_text(''.join(bad))
        try:audit_sources_048(log,ROOT)
        except AssertionError:pass
        else:raise AssertionError('invalid 048 context provenance accepted')
print(f'PASS: exact 048 fit/source positive; {len(mutations)} invalid provenance controls')
