#!/usr/bin/env bash
# Original native-model qualification runner. No vendor code or ABI libraries
# are installed, modified or bundled. Does not build or load a MiSTer core.
set -euo pipefail
[[ $# == 2 ]] || {
  echo 'usage: bash scripts/run_hdmi_handoff_reset_native.sh MODELSIM_BIN ABI5_DEPENDENCIES' >&2
  exit 2
}
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
model_bin="$(cd "$1" && pwd)"
abi_root="$(cd "$2" && pwd)"
for program in vlib vlog vsim; do
  [[ -x "$model_bin/$program" ]] || { echo "Missing native $program" >&2; exit 1; }
done
[[ -f "$model_bin/../modelsim.ini" ]]
[[ -d "$abi_root/lib/i386-linux-gnu" && -d "$abi_root/usr/lib/i386-linux-gnu" ]]
mkdir -p "$root/output_files"
run_dir="$(mktemp -d "$root/output_files/hdmi-native-reset-XXXXXXXX")"
cp "$root/rtl/x1_hdmi_clock_handoff.sv" \
   "$root/verilator/tests/hdmi_handoff_reset_tb.sv" \
   "$root/verilator/tests/hdmi_handoff_reset.do" "$run_dir/"
export LD_LIBRARY_PATH="$abi_root/lib/i386-linux-gnu:$abi_root/usr/lib/i386-linux-gnu"
export MODELSIM="$model_bin/../modelsim.ini"
cd "$run_dir"
matrix() {
  sha256sum x1_hdmi_clock_handoff.sv hdmi_handoff_reset_tb.sv hdmi_handoff_reset.do
  "$model_bin/vlib" work
  "$model_bin/vlog" -sv x1_hdmi_clock_handoff.sv hdmi_handoff_reset_tb.sv
  for video_half in 11640 17500; do
    for hdmi_half in 3366 6250 10000; do
      for phase in 0 1 2 3 4 5 6 7; do
        for stopped_ready in 0 1; do
          "$model_bin/vsim" -c -L cyclonev_ver hdmi_handoff_reset_tb \
            "+VIDEO_HALF=$video_half" "+HDMI_HALF=$hdmi_half" \
            "+PHASE=$phase" "+STOP_READY=$stopped_ready" \
            -do hdmi_handoff_reset.do || return "$?"
        done
      done
    done
  done
  sha256sum x1_hdmi_clock_handoff.sv hdmi_handoff_reset_tb.sv hdmi_handoff_reset.do
}
matrix 2>&1 | tee native.log
python3 "$root/scripts/audit_hdmi_handoff_reset_runs.py" native.log --source-root "$root"
printf 'Native helper evidence: %s\n' "$run_dir"
