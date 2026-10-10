#!/usr/bin/env bash
# Native extracted-policy qualification only; never deploys or installs tools.
set -euo pipefail
[[ $# == 2 || $# == 3 ]] || {
  echo 'usage: bash scripts/run_hdmi_handoff_policy_native.sh MODELSIM_BIN ABI5_DEPENDENCIES [normal|skew|skew-noecho|raw-policy]' >&2
  exit 2
}
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
model_bin="$(cd "$1" && pwd)"
abi_root="$(cd "$2" && pwd)"
profile="${3:-normal}"
emitter_flags=(--native-handoff)
case "$profile" in
  normal) ;;
  skew) emitter_flags+=(--csync-skew-ps 3000000) ;;
  skew-noecho) emitter_flags+=(--csync-skew-ps 3000000 --without-csync-echo) ;;
  raw-policy) emitter_flags+=(--raw-policy) ;;
  *) echo 'Invalid native policy profile' >&2; exit 2 ;;
esac
for program in vlib vlog vsim; do [[ -x "$model_bin/$program" ]]; done
[[ -f "$model_bin/../modelsim.ini" ]]
[[ -d "$abi_root/lib/i386-linux-gnu" && -d "$abi_root/usr/lib/i386-linux-gnu" ]]
mkdir -p "$root/output_files"
run_dir="$(mktemp -d "$root/output_files/hdmi-native-policy-XXXXXXXX")"
mkdir -p "$run_dir/sys" "$run_dir/verilator/tests"
cp "$root/sys/sys_top.v" "$run_dir/sys/"
cp "$root/verilator/tests/emit_hdmi_policy_fixture.py" "$run_dir/verilator/tests/"
cp "$root/rtl/x1_hdmi_clock_handoff.sv" \
   "$root/verilator/tests/hdmi_handoff_policy_tb.sv" \
   "$root/verilator/tests/hdmi_handoff_policy.do" "$run_dir/"
export LD_LIBRARY_PATH="$abi_root/lib/i386-linux-gnu:$abi_root/usr/lib/i386-linux-gnu"
export MODELSIM="$model_bin/../modelsim.ini"
cd "$run_dir"
hash_inputs() {
  sha256sum sys/sys_top.v verilator/tests/emit_hdmi_policy_fixture.py |
    awk '{print "POLICY_SOURCE_HASH", $1, $2}'
  sha256sum hdmi-handoff-policy-native.sv x1_hdmi_clock_handoff.sv \
    hdmi_handoff_policy_tb.sv hdmi_handoff_policy.do
}
matrix() {
  printf 'POLICY_DIAGNOSTIC_PROFILE=%s\n' "$profile"
  python3 verilator/tests/emit_hdmi_policy_fixture.py hdmi-handoff-policy-native.sv "${emitter_flags[@]}"
  hash_inputs
  "$model_bin/vlib" work
  "$model_bin/vlog" -sv x1_hdmi_clock_handoff.sv hdmi-handoff-policy-native.sv hdmi_handoff_policy_tb.sv
  for video_half in 11640 17500; do
    for hdmi_half in 3366 6250 10000; do
      "$model_bin/vsim" -c -L cyclonev_ver hdmi_handoff_policy_tb \
        "+VIDEO_HALF=$video_half" "+HDMI_HALF=$hdmi_half" \
        -do hdmi_handoff_policy.do || return "$?"
    done
  done
  hash_inputs
}
matrix 2>&1 | tee native.log
python3 "$root/scripts/audit_hdmi_handoff_policy_runs.py" native.log \
  --source-root "$root" --fixture hdmi-handoff-policy-native.sv
printf 'Native policy evidence: %s\n' "$run_dir"
