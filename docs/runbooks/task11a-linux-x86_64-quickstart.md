# Task 11A Linux x86_64 Quick Start

## Objective

Complete the CoralNPU Linux upstream gate before starting the real CoralNPU
Verilated Model and gem5 integration:

1. Pull the latest `main` branch from GitHub.
2. Prepare an Ubuntu x86_64 environment and pinned third-party checkouts.
3. Run the first-party unit tests and CoralNPU upstream smoke test.
4. Save environment evidence, logs, and generated-artifact information.
5. Continue Task 11 Step 2 only after the upstream gate passes.

Use
`docs/runbooks/phase1-task11-linux-x86_64-handoff.md`
for the complete Task 11 procedure and architecture context.

## 1. Pull the Latest Main Branch

For a new checkout:

```bash
mkdir -p "${HOME}/work"
cd "${HOME}/work"

git clone https://github.com/jasonyao78/open-npux-tryrun.git open-npux
cd open-npux

git switch main
git pull --ff-only origin main

git status --short --branch
git log --oneline --decorate -6
```

For an existing checkout:

```bash
cd "${HOME}/work/open-npux"

git status --short --branch
# Stop and preserve any local changes before switching branches.

git switch main
git pull --ff-only origin main
```

## 2. Prepare the Ubuntu x86_64 Environment

Verify the host:

```bash
uname -s
uname -m
```

Required output:

- `uname -s`: `Linux`
- `uname -m`: `x86_64`

Run the checked-in environment bootstrap:

```bash
cd "${HOME}/work/open-npux"

tools/env/bootstrap_ubuntu_x86_64.sh
export PATH="${HOME}/.local/bin:${PATH}"

tools/env/check_prereqs.sh
```

The bootstrap script reuses an existing Bazel and Verilator installation. If
Verilator is unavailable, rerun the bootstrap with a reviewed tested ref:

```bash
tools/env/bootstrap_ubuntu_x86_64.sh --verilator-ref <TESTED_VERILATOR_REF>
```

## 3. Prepare Pinned Third-Party Checkouts

```bash
cd "${HOME}/work/open-npux"

tools/env/setup_vendor_checkouts.sh

git -C thirdparty/coralnpu status --short --branch
git -C thirdparty/gem5 status --short --branch
```

Both vendor checkouts must be at their pinned commits and contain no local
modifications. Do not directly modify files under `thirdparty/gem5` or
`thirdparty/coralnpu`.

## 4. Run First-Party Unit Tests

```bash
cd "${HOME}/work/open-npux"
tools/test/run_unit_tests.sh
```

Expected final marker:

```text
OPEN_NPUX_UNIT_TESTS_PASS
```

## 5. Configure Machine-Local Bazel Caches

```bash
export OPEN_NPUX_CORALNPU_REPOSITORY_CACHE="${HOME}/.cache/open-npux/coralnpu-repository"
export OPEN_NPUX_CORALNPU_DISTDIR="${HOME}/.cache/open-npux/coralnpu-distdir"
export OPEN_NPUX_CORALNPU_DISK_CACHE="${HOME}/.cache/open-npux/coralnpu-disk"
```

When `repository_cache` is configured, the smoke runner automatically adds:

```text
--experimental_repository_cache_hardlinks
```

Use `--no-cache` only when diagnosing cache-related failures. An explicit
`--bazel-flag=--noexperimental_repository_cache_hardlinks` disables the
derived hardlinks option.

## 6. Run the Task 11A Upstream Gate

Create an artifact directory outside the Git workspace:

```bash
export REPO_ROOT="${HOME}/work/open-npux"
export TASK11_ARTIFACT_DIR="${HOME}/open-npux-task11-artifacts/$(date +%Y%m%d-%H%M%S)"

mkdir -p "${TASK11_ARTIFACT_DIR}"
cd "${REPO_ROOT}"
```

Capture environment evidence:

```bash
{
  date --iso-8601=seconds
  uname -a
  test -f /etc/os-release && cat /etc/os-release
  git rev-parse HEAD
  git status --short --branch
  git -C thirdparty/gem5 rev-parse HEAD
  git -C thirdparty/gem5 status --short --branch
  git -C thirdparty/coralnpu rev-parse HEAD
  git -C thirdparty/coralnpu status --short --branch
  (cd thirdparty/coralnpu && bazel --version)
  python3 --version
  uv --version
  verilator --version
} | tee "${TASK11_ARTIFACT_DIR}/environment.txt"
```

Run the prerequisite check and upstream smoke:

```bash
set -o pipefail

tools/env/check_prereqs.sh \
  2>&1 | tee "${TASK11_ARTIFACT_DIR}/prereqs.log"

tools/coralnpu/run_upstream_smoke.sh \
  2>&1 | tee "${TASK11_ARTIFACT_DIR}/upstream-smoke.log"
```

## 7. Task 11A Acceptance Criteria

The gate passes only when all of the following are true:

- `tools/env/check_prereqs.sh` finds `git`, `python3`, `uv`, `bazel`, and
  `verilator`.
- The final smoke output contains `OPEN_NPUX_UPSTREAM_SMOKE_PASS`.
- The smoke runner does not print the macOS/arm64 skip message.
- `//examples:coralnpu_v2_hello_world_add_floats` builds.
- `//tests/verilator_sim:core_mini_axi_sim` builds and runs the hello/add ELF.
- `//tests/verilator_sim:rvv_core_mini_axi_sim` builds.
- Both vendor checkouts remain clean.

Verify vendor status again:

```bash
git -C thirdparty/coralnpu status --short --branch
git -C thirdparty/gem5 status --short --branch
```

## 8. Continue After the Gate Passes

Create a development branch from the latest `main`:

```bash
git switch main
git pull --ff-only origin main
git switch -c codex/task11-real-coralnpu-adapter
```

Continue Task 11 Step 2:

1. Build and inspect `//hw_sim:libcoralnpu_simulator.so`.
2. Reuse upstream `CoreMiniAxiWrapper` and `VCoreMiniAxi`.
3. Replace the local facade with a real CoralNPU Verilated Model adapter.
4. Implement the AXI bridge between gem5 and CoralNPU.
5. Keep both vendor checkouts read-only.
6. Add or update tests before each behavior change.

Use this prompt when handing the work to a coding agent:

```text
Continue open-npux Phase 1 on the Linux x86_64 checkout.
Read docs/runbooks/phase1-task11-linux-x86_64-handoff.md and resume Task 11
from Step 2 after the Linux upstream gate. Reuse upstream CoreMiniAxiWrapper
and VCoreMiniAxi. Keep thirdparty/gem5 and thirdparty/coralnpu read-only.
Use short checkpoints and stop for review if the generated artifact layout
changes the planned architecture.
```

After implementation, run the complete verification set before pushing a
branch and opening a pull request for human review.

## 9. Failure Handoff

If any step fails, do not patch vendor sources or run destructive cleanup
commands. Return the complete `${TASK11_ARTIFACT_DIR}` and the output from:

```bash
git rev-parse HEAD
git status --short --branch

git -C thirdparty/coralnpu rev-parse HEAD
git -C thirdparty/coralnpu status --short --branch

git -C thirdparty/gem5 rev-parse HEAD
git -C thirdparty/gem5 status --short --branch
```

Include a short description of:

- The command that failed.
- The expected result.
- The actual result.
- Whether the failure reproduces after a second run.
- Whether either vendor checkout became dirty.
