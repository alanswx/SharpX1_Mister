#!/usr/bin/env bash
# Standalone Linux synthesis/fit probe. Never assembles/deploys a board RBF.
set -euo pipefail
main() {
  local root mode quartus_bin build path result
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  mode="${1:---check}"
  [[ $# -le 1 && ( "$mode" == --check || "$mode" == --build ) ]] || {
    echo 'usage: probe_z_palette_quartus.sh [--check|--build]' >&2; return 2;
  }
  quartus_bin="${QUARTUS_BIN:-/home/alans/intelFPGA_lite/17.0/quartus/bin}"
  for path in quartus_sh quartus_map quartus_fit; do [[ -x "$quartus_bin/$path" ]]; done
  [[ "$("$quartus_bin/quartus_sh" --version)" == *'Version 17.0'* ]]
  for path in palette_ram.qpf palette_ram.qsf palette_ram.sdc; do
    [[ -f "$root/verilator/tests/quartus/z_palette_ram/$path" ]]
  done
  [[ -f "$root/rtl/x1_z_palette_ram.sv" ]]
  [[ "$mode" == --build ]] || { echo 'Preflight passed; no probe started.'; return; }
  if pgrep -x 'quartus_(sh|map|fit|asm|sta)' >/dev/null; then
    echo 'Quartus is already running; coordinate with its owner first.' >&2; return 1;
  fi
  mkdir -p "$root/output_files"
  build="$(mktemp -d "$root/output_files/z-palette-probe-XXXXXXXX")"
  cp "$root/rtl/x1_z_palette_ram.sv" "$build/"
  cp "$root/verilator/tests/quartus/z_palette_ram/"palette_ram.{qpf,qsf,sdc} "$build/"
  cmp "$root/rtl/x1_z_palette_ram.sv" "$build/x1_z_palette_ram.sv"
  for path in palette_ram.qpf palette_ram.qsf palette_ram.sdc; do
    cmp "$root/verilator/tests/quartus/z_palette_ram/$path" "$build/$path"
  done
  (
    cd "$build"
    sha256sum x1_z_palette_ram.sv palette_ram.qpf palette_ram.qsf palette_ram.sdc > input.sha256
  )
  {
    printf '%s\n' "source_commit=$(git -C "$root" rev-parse HEAD)" \
      "host=$(hostname)" "started_utc=$(date -u +%FT%TZ)" \
      'scope=standalone storage inference/fit; no board RBF or timing acceptance'
    "$quartus_bin/quartus_sh" --version
    sha256sum "$build/input.sha256" "$root/scripts/probe_z_palette_quartus.sh"
  } > "$build/probe-manifest.txt"
  git -C "$root" status --short > "$build/git-status.txt"
  printf 'Probe snapshot: %s\n' "$build"
  export PATH="$quartus_bin:$PATH"
  cd "$build"
  set +e
  quartus_map --write_settings_files=off palette_ram 2>&1 | tee map.log
  result=${PIPESTATUS[0]}
  if [[ $result -eq 0 ]]; then
    quartus_fit --write_settings_files=off palette_ram 2>&1 | tee fit.log
    result=${PIPESTATUS[0]}
  fi
  set -e
  printf '%s\n' "finished_utc=$(date -u +%FT%TZ)" "exit_status=$result" >> probe-manifest.txt
  sha256sum -c input.sha256 > input-after.txt
  printf 'Evidence: %s\n' "$build"
  return "$result"
}
main "$@"
