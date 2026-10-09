#!/usr/bin/env bash
# Original standalone storage probe using the existing local Apple runtime.
# No image/tool installation, board assembly, timing signoff or deployment.
set -euo pipefail
main() {
  local root mode install image build path result
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  mode="${1:---check}"
  [[ $# -le 1 && ( "$mode" == --check || "$mode" == --build ) ]] || {
    echo 'usage: probe_z_palette_quartus_apple.sh [--check|--build]' >&2; return 2;
  }
  install="${QUARTUS_CACHE_DIR:-/Users/alans/dev2/apple-containers-example/build/quartus}/intelFPGA_lite"
  image=docker.io/library/quartus17-runtime:apple-amd64
  [[ -x "$install/17.0/quartus/bin/quartus_map" && -x "$install/17.0/quartus/bin/quartus_fit" ]]
  command -v container >/dev/null
  container image inspect "$image" >/dev/null
  [[ "$mode" == --build ]] || { echo 'Preflight passed; no probe started.'; return; }
  # The caller must inspect running containers/coordinate other builds first.
  mkdir -p "$root/output_files"
  build="$(mktemp -d "$root/output_files/z-palette-apple-XXXXXXXX")"
  cp "$root/rtl/x1_z_palette_ram.sv" "$build/"
  cp "$root/verilator/tests/quartus/z_palette_ram/"palette_ram.{qpf,qsf,sdc} "$build/"
  cmp "$root/rtl/x1_z_palette_ram.sv" "$build/x1_z_palette_ram.sv"
  for path in palette_ram.qpf palette_ram.qsf palette_ram.sdc; do
    cmp "$root/verilator/tests/quartus/z_palette_ram/$path" "$build/$path"
  done
  (cd "$build"; shasum -a 256 x1_z_palette_ram.sv palette_ram.qpf palette_ram.qsf palette_ram.sdc > input.sha256)
  container image inspect "$image" > "$build/runtime-image.json"
  {
    printf '%s\n' "source_commit=$(git -C "$root" rev-parse HEAD)" "started_utc=$(date -u +%FT%TZ)" \
      'scope=standalone storage inference/fit; no board RBF or timing acceptance'
    shasum -a 256 "$build/input.sha256" "$build/runtime-image.json" "$root/scripts/probe_z_palette_quartus_apple.sh"
  } > "$build/probe-manifest.txt"
  git -C "$root" status --short > "$build/git-status.txt"
  printf 'Probe snapshot: %s\n' "$build"
  set +e
  container run --arch amd64 --rm --cpus 4 --memory 4g \
    --mount "type=bind,source=$install,target=/opt/intelFPGA_lite,readonly" \
    --mount "type=bind,source=$build,target=/work" --workdir /work "$image" \
    sh -euc 'quartus_sh --version; quartus_map --parallel=1 --write_settings_files=off palette_ram; quartus_fit --parallel=4 --write_settings_files=off palette_ram' \
    2>&1 | tee "$build/probe.log"
  result=${PIPESTATUS[0]}
  set -e
  printf '%s\n' "finished_utc=$(date -u +%FT%TZ)" "exit_status=$result" >> "$build/probe-manifest.txt"
  (cd "$build"; shasum -a 256 -c input.sha256 > input-after.txt)
  printf 'Evidence: %s\n' "$build"
  return "$result"
}
main "$@"
