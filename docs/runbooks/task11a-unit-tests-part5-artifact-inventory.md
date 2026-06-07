# Task 11A Unit Tests 与 Part 5 Artifact Inventory 操作指导

## 目标

在已经跑通 CoralNPU upstream smoke 的 Linux x86_64 机器上，补齐以下
Task 11A 验收证据：

1. 使用仓库规定的 `uv` 环境运行完整 unit tests。
2. 构建 `libcoralnpu_simulator.so`。
3. 收集 `CoreMiniAxiWrapper`、`VCoreMiniAxi`、共享库和模拟器的生成路径。
4. 将日志和 inventory 文件回传，用于后续 Task 11 Step 2 的真实 gem5
   adapter 集成。

本轮只收集证据和生成物信息，不修改 `thirdparty/gem5` 或
`thirdparty/coralnpu`，也不开始 adapter 编码。

## 1. 更新并检查工作区

```bash
export REPO_ROOT="${HOME}/work/open-npux"
cd "${REPO_ROOT}"

git status --short --branch
git switch main
git pull --ff-only origin main

git rev-parse HEAD
git status --short --branch
```

要求：

- 主仓工作区必须干净。
- 如果 `git status` 显示本地修改，先停止并保留现场，不要强制覆盖。
- 最新代码中的 `check_prereqs.sh` 应包含只读 vendor 检查：

  ```bash
  git grep -- '--check-only' tools/env/check_prereqs.sh
  ```

准备并验证 pinned vendor checkouts：

```bash
tools/env/setup_vendor_checkouts.sh
tools/env/check_prereqs.sh
```

`setup_vendor_checkouts.sh` 是幂等操作。已经存在且位于正确 pinned commit
的 clean checkout 不会再次 clone 或 fetch。

再次确认两个 vendor checkout 没有修改：

```bash
git -C thirdparty/coralnpu rev-parse HEAD
git -C thirdparty/coralnpu status --short --branch

git -C thirdparty/gem5 rev-parse HEAD
git -C thirdparty/gem5 status --short --branch
```

预期 pinned commits：

| Project | Commit |
|---|---|
| CoralNPU | `406540cc7d3c7e885ba155a5ee11909d3cb5ee01` |
| gem5 | `c8222cc67a399bfc01e8658dd14b30d5bfd634f9` |

## 2. 创建证据目录

不要把日志写入 Git 工作区。

```bash
export TASK11_ARTIFACT_DIR="${HOME}/open-npux-task11-artifacts/$(date +%Y%m%d-%H%M%S)"
mkdir -p "${TASK11_ARTIFACT_DIR}"

printf 'REPO_ROOT=%s\nTASK11_ARTIFACT_DIR=%s\n' \
  "${REPO_ROOT}" "${TASK11_ARTIFACT_DIR}"
```

记录本轮执行环境：

```bash
cd "${REPO_ROOT}"

{
  date --iso-8601=seconds
  uname -a
  test -f /etc/os-release && cat /etc/os-release
  git rev-parse HEAD
  git status --short --branch
  git -C thirdparty/coralnpu rev-parse HEAD
  git -C thirdparty/coralnpu status --short --branch
  git -C thirdparty/gem5 rev-parse HEAD
  git -C thirdparty/gem5 status --short --branch
  python3 --version
  uv --version
  uv run python --version
  (cd thirdparty/coralnpu && bazel --version)
  verilator --version
} | tee "${TASK11_ARTIFACT_DIR}/environment-unit-part5.txt"
```

系统自带 `python3` 可以仍是 `3.8.10`，但 `uv run python --version` 必须满足
项目的 Python `>=3.11` 要求。

## 3. 运行 Unit Tests

```bash
cd "${REPO_ROOT}"
set -o pipefail

tools/test/run_unit_tests.sh \
  2>&1 | tee "${TASK11_ARTIFACT_DIR}/unit-tests.log"
```

成功标准：

- 命令退出码为 `0`。
- pytest 没有 failed 或 error。
- 日志末尾包含：

  ```text
  OPEN_NPUX_UNIT_TESTS_PASS
  ```

检查 marker：

```bash
grep -F 'OPEN_NPUX_UNIT_TESTS_PASS' \
  "${TASK11_ARTIFACT_DIR}/unit-tests.log"
```

如果 `uv` 因 Python 版本或下载问题失败，保留完整
`unit-tests.log`，不要改用系统 Python 直接运行 pytest 来绕过问题。

## 4. 配置 Part 5 Bazel Cache Flags

`tools/coralnpu/run_upstream_smoke.sh` 会读取缓存环境变量，但下面的 Part 5
使用直接 Bazel 命令，因此需要显式组装相同 flags。

```bash
export OPEN_NPUX_CORALNPU_REPOSITORY_CACHE="${OPEN_NPUX_CORALNPU_REPOSITORY_CACHE:-${HOME}/.cache/open-npux/coralnpu-repository}"
export OPEN_NPUX_CORALNPU_DISTDIR="${OPEN_NPUX_CORALNPU_DISTDIR:-${HOME}/.cache/open-npux/coralnpu-distdir}"
export OPEN_NPUX_CORALNPU_DISK_CACHE="${OPEN_NPUX_CORALNPU_DISK_CACHE:-${HOME}/.cache/open-npux/coralnpu-disk}"

mkdir -p \
  "${OPEN_NPUX_CORALNPU_REPOSITORY_CACHE}" \
  "${OPEN_NPUX_CORALNPU_DISTDIR}" \
  "${OPEN_NPUX_CORALNPU_DISK_CACHE}"

BAZEL_CACHE_FLAGS=(
  "--repository_cache=${OPEN_NPUX_CORALNPU_REPOSITORY_CACHE}"
  "--distdir=${OPEN_NPUX_CORALNPU_DISTDIR}"
  "--disk_cache=${OPEN_NPUX_CORALNPU_DISK_CACHE}"
  "--experimental_repository_cache_hardlinks"
)
```

不要在本轮执行 `bazel clean`。本轮目标是构建和记录真实生成路径，不是进行
cold-cache 测试。

## 5. 构建共享库

```bash
cd "${REPO_ROOT}/thirdparty/coralnpu"
set -o pipefail

bazel build "${BAZEL_CACHE_FLAGS[@]}" \
  //hw_sim:libcoralnpu_simulator.so \
  2>&1 | tee "${TASK11_ARTIFACT_DIR}/libcoralnpu-simulator-build.log"
```

成功标准：

- 命令退出码为 `0`。
- 日志包含 `Build completed successfully`。
- Bazel 报告 `//hw_sim:libcoralnpu_simulator.so` 构建成功。

## 6. 收集 Bazel Cquery 与生成物清单

```bash
cd "${REPO_ROOT}/thirdparty/coralnpu"
set -o pipefail

bazel cquery "${BAZEL_CACHE_FLAGS[@]}" --output=files \
  //hdl/chisel/src/coralnpu:core_mini_axi_cc_library_cc \
  | sort \
  | tee "${TASK11_ARTIFACT_DIR}/core-mini-axi-cquery.txt"

bazel cquery "${BAZEL_CACHE_FLAGS[@]}" --output=files \
  //hw_sim:libcoralnpu_simulator.so \
  | sort \
  | tee "${TASK11_ARTIFACT_DIR}/libcoralnpu-simulator-cquery.txt"

find -L bazel-bin -type f \
  \( \
    -name 'VCoreMiniAxi*' \
    -o -name 'CoreMiniAxi.sv' \
    -o -name 'libcoralnpu_simulator.so' \
    -o -name 'core_mini_axi_sim' \
  \) \
  | sort \
  | tee "${TASK11_ARTIFACT_DIR}/generated-files.txt"
```

检查清单不是空文件：

```bash
test -s "${TASK11_ARTIFACT_DIR}/core-mini-axi-cquery.txt"
test -s "${TASK11_ARTIFACT_DIR}/libcoralnpu-simulator-cquery.txt"
test -s "${TASK11_ARTIFACT_DIR}/generated-files.txt"
```

## 7. 收集共享库和生成文件元数据

记录 upstream wrapper 接口和 BUILD 依赖边界：

```bash
cd "${REPO_ROOT}/thirdparty/coralnpu"

{
  realpath hw_sim/core_mini_axi_wrapper.h
  sha256sum hw_sim/core_mini_axi_wrapper.h
  echo
  grep -nE \
    'class CoreMiniAxiWrapper|void Reset|void Step|void Write|Read\(|RegisterReadCallback|RegisterWriteCallback|WaitForTermination' \
    hw_sim/core_mini_axi_wrapper.h
  echo
  sed -n '25,130p' hw_sim/BUILD
} | tee "${TASK11_ARTIFACT_DIR}/core-mini-axi-wrapper-interface.txt"
```

这份文件用于确认 wrapper 已经提供 reset、step、AXI slave 访问和 AXI master
callback 边界，并记录共享库 target 的实际 Bazel 依赖关系。

记录生成文件类型和校验值：

```bash
cd "${REPO_ROOT}/thirdparty/coralnpu"

{
  echo '=== generated file metadata ==='
  while IFS= read -r artifact; do
    test -f "${artifact}" || continue
    printf '\n--- %s ---\n' "${artifact}"
    file "${artifact}"
    sha256sum "${artifact}"
  done < "${TASK11_ARTIFACT_DIR}/generated-files.txt"
} | tee "${TASK11_ARTIFACT_DIR}/generated-file-metadata.txt"
```

收集共享库动态依赖：

```bash
cd "${REPO_ROOT}/thirdparty/coralnpu"

LIBCORALNPU_PATH="$(
  find -L bazel-bin -type f -name 'libcoralnpu_simulator.so' | head -n 1
)"

test -n "${LIBCORALNPU_PATH}"
test -f "${LIBCORALNPU_PATH}"

{
  printf 'LIBCORALNPU_PATH=%s\n' "${LIBCORALNPU_PATH}"
  file "${LIBCORALNPU_PATH}"
  ldd "${LIBCORALNPU_PATH}"
  readelf -h "${LIBCORALNPU_PATH}"
} | tee "${TASK11_ARTIFACT_DIR}/libcoralnpu-simulator-metadata.txt"

nm -D -C "${LIBCORALNPU_PATH}" \
  | grep -E 'CoralNPU|coralnpu|CoreMiniAxi' \
  | tee "${TASK11_ARTIFACT_DIR}/libcoralnpu-simulator-symbols.txt" \
  || true
```

这些文件用于下一步确定 gem5 SCons 的 include、library 和 runtime dependency
路径。不要根据经验猜测 Bazel 输出路径。

## 8. 最终验证

```bash
cd "${REPO_ROOT}"

grep -F 'OPEN_NPUX_UNIT_TESTS_PASS' \
  "${TASK11_ARTIFACT_DIR}/unit-tests.log"

grep -F 'Build completed successfully' \
  "${TASK11_ARTIFACT_DIR}/libcoralnpu-simulator-build.log"

test -s "${TASK11_ARTIFACT_DIR}/core-mini-axi-cquery.txt"
test -s "${TASK11_ARTIFACT_DIR}/libcoralnpu-simulator-cquery.txt"
test -s "${TASK11_ARTIFACT_DIR}/generated-files.txt"
test -s "${TASK11_ARTIFACT_DIR}/core-mini-axi-wrapper-interface.txt"
test -s "${TASK11_ARTIFACT_DIR}/generated-file-metadata.txt"
test -s "${TASK11_ARTIFACT_DIR}/libcoralnpu-simulator-metadata.txt"

git status --short --branch
git -C thirdparty/coralnpu status --short --branch
git -C thirdparty/gem5 status --short --branch
```

验收标准：

- Unit tests 通过并包含 `OPEN_NPUX_UNIT_TESTS_PASS`。
- `libcoralnpu_simulator.so` 构建成功。
- 三份核心 inventory 文件非空。
- Wrapper 接口和 BUILD 依赖边界已记录。
- 共享库 metadata 和动态依赖记录完整。
- 主仓和两个 vendor checkout 均没有新增修改。

## 9. 回传清单

请回传整个 `${TASK11_ARTIFACT_DIR}`。至少应包含：

```text
environment-unit-part5.txt
unit-tests.log
libcoralnpu-simulator-build.log
core-mini-axi-cquery.txt
libcoralnpu-simulator-cquery.txt
generated-files.txt
core-mini-axi-wrapper-interface.txt
generated-file-metadata.txt
libcoralnpu-simulator-metadata.txt
libcoralnpu-simulator-symbols.txt
```

回传时同时说明：

1. 主仓 commit ID。
2. Unit-test pytest 汇总行。
3. 是否出现 `OPEN_NPUX_UNIT_TESTS_PASS`。
4. `LIBCORALNPU_PATH` 的实际路径。
5. 两个 vendor checkout 是否保持 clean。
6. 是否遇到 warning、失败或需要人工判断的生成路径。

可以将整个证据目录打包，并生成校验值：

```bash
ARTIFACT_ARCHIVE="${TASK11_ARTIFACT_DIR}.tar.gz"

tar -C "$(dirname "${TASK11_ARTIFACT_DIR}")" \
  -czf "${ARTIFACT_ARCHIVE}" \
  "$(basename "${TASK11_ARTIFACT_DIR}")"

sha256sum "${ARTIFACT_ARCHIVE}" \
  | tee "${ARTIFACT_ARCHIVE}.sha256"

printf 'archive: %s\nsha256: %s\n' \
  "${ARTIFACT_ARCHIVE}" "${ARTIFACT_ARCHIVE}.sha256"
```

如果任意步骤失败，保留完整日志并停止。不要修改 vendor 源码，不要执行
`git reset --hard`、`git checkout --` 或 `bazel clean`。
