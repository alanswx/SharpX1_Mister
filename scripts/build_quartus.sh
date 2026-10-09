#!/usr/bin/env bash
# Build a private, hashed working-tree snapshot with the installed Quartus 17.
# Does not install tools, fetch images, or accept licenses.
set -euo pipefail
main() {
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILDER_ROOT="${QUARTUS_BUILDER_ROOT:-/Users/alans/dev2/apple-containers-example}"
INSTALL_ROOT="${QUARTUS_CACHE_DIR:-$BUILDER_ROOT/build/quartus}/intelFPGA_lite"
IMAGE=docker.io/library/quartus17-runtime:apple-amd64
REVISION="${QUARTUS_REVISION:-sharpx1}"
case "$REVISION" in
  sharpx1|sharpx1_single|sharpx1_turbo_single|sharpx1_turbo_video|sharpx1_turbo_dma_single|sharpx1_turbo_fm) ;;
  *) echo 'Unsupported QUARTUS_REVISION' >&2; exit 2 ;;
esac
[[ -f "$ROOT/$REVISION.qsf" ]] || { echo "Missing $REVISION.qsf" >&2; exit 2; }
[[ -x "$INSTALL_ROOT/17.0/quartus/bin/quartus_sh" ]] || {
  echo 'Installed Quartus 17 is required; this script will not install it.' >&2; exit 1;
}
command -v container >/dev/null
container image inspect "$IMAGE" >/dev/null
mkdir -p "$ROOT/output_files"
BUILD_DIR="$(mktemp -d "$ROOT/output_files/quartus-XXXXXXXX")"
SNAPSHOT="$BUILD_DIR/source"
mkdir "$SNAPSHOT"
container image inspect "$IMAGE" > "$BUILD_DIR/runtime-image.json"
cd "$ROOT"
# Preserve relative IP/firmware paths and notices; omit downloaded private games,
# old simulator outputs, and unrelated sibling trees. Include dirty/untracked RTL.
git ls-files -co --exclude-standard | LC_ALL=C sort -u |
  awk '/^(rtl\/|sys\/|bios\/|references\/chip-src\/)/ || /^[^\/]+\.(qpf|qsf|qip|sdc|sv|v|tcl)$/ || /^(LICENSE|AGENTS.md)$/' > "$BUILD_DIR/input-files.txt"
hash_inputs() {
  local base="$1" path
  (cd "$base"; while IFS= read -r path; do shasum -a 256 "$path"; done < "$BUILD_DIR/input-files.txt")
}
hash_inputs "$ROOT" > "$BUILD_DIR/source-before.sha256"
tar -cf - -T "$BUILD_DIR/input-files.txt" | tar -xf - -C "$SNAPSHOT"
hash_inputs "$ROOT" > "$BUILD_DIR/source-after.sha256"
hash_inputs "$SNAPSHOT" > "$BUILD_DIR/input.sha256"
cmp "$BUILD_DIR/source-before.sha256" "$BUILD_DIR/source-after.sha256"
cmp "$BUILD_DIR/source-before.sha256" "$BUILD_DIR/input.sha256"
git status --short > "$BUILD_DIR/git-status.txt"
{
  echo "source_commit=$(git rev-parse HEAD)"
  echo "snapshot=$SNAPSHOT"
  echo "input_manifest_sha256=$(shasum -a 256 "$BUILD_DIR/input.sha256" | awk '{print $1}')"
  echo "runtime=$IMAGE"
  echo "runtime_identity_sha256=$(shasum -a 256 "$BUILD_DIR/runtime-image.json" | awk '{print $1}')"
  echo "project=sharpx1 revision=$REVISION map_parallel=1 fit_parallel=8"
  echo 'device=5CSEBA6U23I7 seed=1'
  echo "container_cpus=${QUARTUS_CPUS:-$(sysctl -n hw.ncpu)} container_memory=${QUARTUS_MEMORY:-16g}"
  echo "sidecar_sha256=$(shasum -a 256 "$ROOT/scripts/build_quartus.sh" | awk '{print $1}')"
  echo "builder_sha256=$(shasum -a 256 "$BUILDER_ROOT/scripts/quartus-core-apple.sh" | awk '{print $1}')"
  echo "started_utc=$(date -u +%FT%TZ)"
} > "$BUILD_DIR/build-manifest.txt"
echo "Build snapshot: $BUILD_DIR"
export QUARTUS_FIT_THREADS=8
set +e
"$BUILDER_ROOT/scripts/quartus-core-apple.sh" "$SNAPSHOT" sharpx1 "$REVISION" 2>&1 | tee "$BUILD_DIR/build.log"
RESULT=${PIPESTATUS[0]}
set -e
{
  echo "finished_utc=$(date -u +%FT%TZ)"
  echo "exit_status=$RESULT"
  if [[ -f "$SNAPSHOT/build_id.v" ]]; then shasum -a 256 "$SNAPSHOT/build_id.v"; fi
  if [[ -f "$SNAPSHOT/output_files/$REVISION.rbf" ]]; then shasum -a 256 "$SNAPSHOT/output_files/$REVISION.rbf"; fi
} >> "$BUILD_DIR/build-manifest.txt"
echo "Evidence: $BUILD_DIR"
exit "$RESULT"
}
# Parse the complete function before starting a long build: edits to this script
# during a running build must not change the commands resumed after the builder.
main "$@"
