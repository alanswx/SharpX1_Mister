#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Project-local ABI5 dependencies, not a system installation or ABI symlink.
# Official package metadata (consulted October 9, 2026):
# https://packages.ubuntu.com/jammy/i386/libncurses5/download
# https://packages.ubuntu.com/jammy/i386/libtinfo5/download
set -eu
if [ "$#" -ne 2 ]; then
    echo 'usage: setup_modelsim_runtime.sh ABS_MODELSIM_ROOT NEW_ABS_RUNTIME_DIR' >&2
    exit 2
fi
x1_ms_root=$1
x1_ms_runtime=$2
case "$x1_ms_root" in /*) ;; *) echo 'ModelSim root must be absolute' >&2; exit 2;; esac
case "$x1_ms_runtime" in /*) ;; *) echo 'Runtime directory must be absolute' >&2; exit 2;; esac
if [ ! -x "$x1_ms_root/linuxaloem/vsim" ] || [ -e "$x1_ms_runtime" ]; then
    echo 'Expected installed linuxaloem runtime and a new dependency directory' >&2
    exit 2
fi
mkdir "$x1_ms_runtime"
cd "$x1_ms_runtime"
for x1_ms_pkg in libncurses5 libtinfo5; do
    x1_ms_deb=${x1_ms_pkg}_6.3-2ubuntu0.3_i386.deb
    curl --fail --location --proto '=https' --tlsv1.2 \
        "https://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/$x1_ms_deb" \
        --output "$x1_ms_deb"
    case "$x1_ms_pkg" in
        libncurses5) x1_ms_sha=3ccbc52ca31acf0e8c915ec903c361f49b5a56ad8e81364f9483a8bda91dee7f;;
        libtinfo5) x1_ms_sha=67b85304831409ba28dcdd415af8c0e849b8d0c1ef3d6427c3c81b978d1ee176;;
    esac
    printf '%s  %s\n' "$x1_ms_sha" "$x1_ms_deb" | sha256sum -c -
    dpkg-deb --extract "$x1_ms_deb" dependencies
done
env LD_LIBRARY_PATH="$x1_ms_runtime/dependencies/lib/i386-linux-gnu:$x1_ms_runtime/dependencies/usr/lib/i386-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$x1_ms_root/linuxaloem/vsim" -version
