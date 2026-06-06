#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}/thirdparty/coralnpu"

host_os="$(uname -s)"
host_arch="$(uname -m)"

if [[ "${OPEN_NPUX_FORCE_CORALNPU_SMOKE:-0}" != "1" ]]; then
  if [[ "${host_os}" != "Linux" || "${host_arch}" != "x86_64" ]]; then
    echo "skip: CoralNPU upstream Bazel toolchain requires Linux x86_64 execution."
    echo "host: ${host_os} ${host_arch}"
    echo "set OPEN_NPUX_FORCE_CORALNPU_SMOKE=1 to run anyway."
    exit 0
  fi
fi

# -----------------------------
# Cache settings
# -----------------------------
export OPEN_NPUX_CORALNPU_REPOSITORY_CACHE=/hdd_8T/michael/bazel-cache/coralnpu-repo-cache
export OPEN_NPUX_CORALNPU_DISTDIR=/hdd_8T/michael/bazel-cache/coralnpu-distdir
export OPEN_NPUX_CORALNPU_DISK_CACHE=/hdd_8T/michael/bazel-cache/coralnpu-disk-cache
export OPEN_NPUX_CORALNPU_EXTRA_BAZEL_FLAGS="--experimental_repository_cache_hardlinks"

# -----------------------------
# Bazel setup
# -----------------------------
bazel_cmd="${BAZEL:-bazel}"

if ! command -v "${bazel_cmd}" >/dev/null 2>&1; then
  echo "ERROR: bazel not found: ${bazel_cmd}" >&2
  exit 1
fi

bazel_flags=()

if [[ -n "${OPEN_NPUX_CORALNPU_REPOSITORY_CACHE:-}" ]]; then
  mkdir -p "${OPEN_NPUX_CORALNPU_REPOSITORY_CACHE}"
  bazel_flags+=("--repository_cache=${OPEN_NPUX_CORALNPU_REPOSITORY_CACHE}")
fi

if [[ -n "${OPEN_NPUX_CORALNPU_DISTDIR:-}" ]]; then
  mkdir -p "${OPEN_NPUX_CORALNPU_DISTDIR}"
  bazel_flags+=("--distdir=${OPEN_NPUX_CORALNPU_DISTDIR}")
fi

if [[ -n "${OPEN_NPUX_CORALNPU_DISK_CACHE:-}" ]]; then
  mkdir -p "${OPEN_NPUX_CORALNPU_DISK_CACHE}"
  bazel_flags+=("--disk_cache=${OPEN_NPUX_CORALNPU_DISK_CACHE}")
fi

# safer parsing for flags
if [[ -n "${OPEN_NPUX_CORALNPU_EXTRA_BAZEL_FLAGS:-}" ]]; then
  IFS=' ' read -r -a extra_flags <<< "${OPEN_NPUX_CORALNPU_EXTRA_BAZEL_FLAGS}"
  bazel_flags+=("${extra_flags[@]}")
fi

# -----------------------------
# Correct Bazel invocation ✅
# -----------------------------
run_bazel() {
  local cmd="$1"
  shift
  echo "${bazel_cmd}" "${cmd}" "${bazel_flags[@]}" "$@"
  "${bazel_cmd}" "${cmd}" "${bazel_flags[@]}" "$@"
}

# -----------------------------
# Build
# -----------------------------
run_bazel build //examples:coralnpu_v2_hello_world_add_floats
run_bazel build //tests/verilator_sim:core_mini_axi_sim
run_bazel build //tests/verilator_sim:rvv_core_mini_axi_sim

# -----------------------------
# Run simulation
# -----------------------------
sim="bazel-bin/tests/verilator_sim/core_mini_axi_sim"

# 优先使用确定路径（更稳定）
binary="bazel-bin/examples/coralnpu_v2_hello_world_add_floats.elf"

# fallback（保险）
if [[ ! -f "${binary}" ]]; then
  binary="$(find -L bazel-out -path '*examples/coralnpu_v2_hello_world_add_floats.elf' -type f | head -n 1 || true)"
fi

if [[ -z "${binary}" || ! -f "${binary}" ]]; then
  echo "failed to locate hello_world_add_floats ELF" >&2
  exit 1
fi

echo "[INFO] Running simulation with binary: ${binary}"
"${sim}" --binary "${binary}"
``
