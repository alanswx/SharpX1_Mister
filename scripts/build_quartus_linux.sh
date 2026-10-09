#!/usr/bin/env bash
# Native Linux build; never deploys to MiSTer or modifies the source checkout.
set -euo pipefail
main() {
  local root mode revision quartus_bin version build snapshot result path
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  mode="${1:---check}"
  [[ $# -le 1 && ( "$mode" == --check || "$mode" == --build ) ]] || {
    echo 'usage: build_quartus_linux.sh [--check|--build]' >&2; return 2;
  }
  revision="${QUARTUS_REVISION:-sharpx1}"
  case "$revision" in
    sharpx1|sharpx1_single|sharpx1_turbo_single|sharpx1_turbo_video|sharpx1_turbo_dma_single) ;;
    *) echo 'Unsupported revision' >&2; return 2 ;;
  esac
  quartus_bin="${QUARTUS_BIN:-/home/alans/intelFPGA_lite/17.0/quartus/bin}"
  for path in quartus_sh quartus_map quartus_fit quartus_asm quartus_sta; do
    [[ -x "$quartus_bin/$path" ]] || { echo "Missing $quartus_bin/$path" >&2; return 1; }
  done
  for path in git tar sha256sum cmp tee; do command -v "$path" >/dev/null; done
  [[ -f "$root/$revision.qsf" && -f "$root/sharpx1.qpf" ]]
  [[ -d "$quartus_bin/../common/devinfo/cyclonev" ]] || {
    echo 'Cyclone V device support is missing' >&2; return 1;
  }
  version="$("$quartus_bin/quartus_sh" --version)"
  [[ "$version" == *'Version 17.0'* ]] || { echo "$version" >&2; return 1; }
  printf '%s\n' "$version" "project=sharpx1 revision=$revision source_commit=$(git -C "$root" rev-parse HEAD)"
  [[ "$mode" == --build ]] || { echo 'Preflight passed; no build started.'; return 0; }
  # Refuse competing Quartus jobs on this shared host. This is a best-effort
  # check, not a host-wide lock: coordinate before starting another project.
  if pgrep -x 'quartus_(sh|map|fit|asm|sta)' >/dev/null; then
    echo 'Quartus is already running; coordinate with its owner first.' >&2; return 1;
  fi
  mkdir -p "$root/output_files"
  build="$(mktemp -d "$root/output_files/quartus-linux-XXXXXXXX")"
  snapshot="$build/source"
  mkdir "$snapshot"
  cd "$root"
  git ls-files -co --exclude-standard | LC_ALL=C sort -u |
    awk '/^(rtl\/|sys\/|bios\/|references\/chip-src\/)/ || /^[^\/]+\.(qpf|qsf|qip|sdc|sv|v|tcl)$/ || /^(LICENSE|AGENTS.md)$/' > "$build/input-files.txt"
  hash_inputs() {
    (cd "$1"; while IFS= read -r path; do sha256sum "$path"; done < "$build/input-files.txt")
  }
  hash_inputs "$root" > "$build/source-before.sha256"
  tar -cf - -T "$build/input-files.txt" | tar -xf - -C "$snapshot"
  hash_inputs "$root" > "$build/source-after.sha256"
  hash_inputs "$snapshot" > "$build/input.sha256"
  cmp "$build/source-before.sha256" "$build/source-after.sha256"
  cmp "$build/source-before.sha256" "$build/input.sha256"
  git status --short > "$build/git-status.txt"
  {
    printf '%s\n' "source_commit=$(git rev-parse HEAD)" "snapshot=$snapshot" \
      "host=$(hostname)" "project=sharpx1 revision=$revision" \
      'flow=quartus_sh --flow compile (including project flow hooks)' \
      "started_utc=$(date -u +%FT%TZ)" "$version"
    sha256sum "$build/input.sha256" "$root/scripts/build_quartus_linux.sh"
  } > "$build/build-manifest.txt"
  printf 'Build snapshot: %s\n' "$build"
  export PATH="$quartus_bin:$PATH"
  cd "$snapshot"
  set +e
  quartus_sh --flow compile sharpx1 -c "$revision" 2>&1 | tee "$build/build.log"
  result=${PIPESTATUS[0]}
  set -e
  {
    printf '%s\n' "finished_utc=$(date -u +%FT%TZ)" "exit_status=$result"
    if [[ -f build_id.v ]]; then sha256sum build_id.v; fi
    if [[ -f "output_files/$revision.rbf" ]]; then sha256sum "output_files/$revision.rbf"; fi
  } >> "$build/build-manifest.txt"
  printf 'Evidence: %s\n' "$build"
  return "$result"
}
main "$@"
