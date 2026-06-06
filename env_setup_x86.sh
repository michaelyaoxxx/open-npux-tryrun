#!/usr/bin/env bash
set -e

################################################################################
# Dev Env Bootstrap Script
#
# Version History:
# v0.5  初版（apt + clang + python + bazel）
# v0.6  支持CODENAME + 环境变量检测
# v0.7  引入fallback + 日志系统 + bazel改进
# v0.8  用户级安装 (~/.local/bin) + PATH持久化优化
# v0.9  模块化（step_*）+ APT清理 + 工程结构
# v0.9.1 (当前)
#   ✅ 新增 Verilator toolchain（RTLSim必备）
#   ✅ 补齐 flex/bison/autoconf/libfl/zlib 依赖
#   ✅ 保持脚本结构不变（严格增量改动）
#   ✅ 增加help2man安装
################################################################################

VERSION="v0.9.1"

echo "=============================="
echo "🚀 Dev Env Bootstrap ($VERSION)"
echo "=============================="

# -----------------------------
# Detect OS
# -----------------------------
. /etc/os-release
CODENAME=$VERSION_CODENAME
echo "✅ OS: $PRETTY_NAME ($CODENAME)"

# -----------------------------
# Logging
# -----------------------------
log()  { echo -e "[INFO] $1"; }
warn() { echo -e "[WARN] $1"; }

# -----------------------------
# Helpers
# -----------------------------
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# -----------------------------
# Paths
# -----------------------------
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

log "Using shell rc: $SHELL_RC"
log "Using local bin: $LOCAL_BIN"

# -----------------------------
# PATH management
# -----------------------------
ensure_local_bin_in_path() {
    export PATH="$LOCAL_BIN:$PATH"

    if [ -n "$CI" ]; then
        log "CI detected → skip rc modification"
        return
    fi

    if echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
        log "~/.local/bin already in PATH"
    fi

    if ! grep -q '\.local/bin' "$SHELL_RC" 2>/dev/null; then
        log "Persisting ~/.local/bin to $SHELL_RC"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    else
        log "~/.local/bin already configured in $SHELL_RC"
    fi
}

# -----------------------------
# APT helpers
# -----------------------------
clean_broken_sources() {
    if [ -f /etc/apt/sources.list.d/jenkins.list ]; then
        warn "Removing broken Jenkins apt source"
        sudo rm -f /etc/apt/sources.list.d/jenkins.list
    fi
}

setup_apt_sources() {
    log "Configuring APT source (Aliyun)..."

    sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $CODENAME-security main restricted universe multiverse
EOF
}

install_pkg() {
    log "Installing: $*"

    if sudo apt install -y "$@"; then
        return
    fi

    warn "APT failed → fallback to official"

    sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://archive.ubuntu.com/ubuntu/ $CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-security main restricted universe multiverse
EOF

    sudo apt update -y
    sudo apt install -y "$@"
}

# -----------------------------
# Step 1: Base system
# -----------------------------
step_base() {
    log "Step 1: Base system"

    clean_broken_sources
    setup_apt_sources

    sudo apt update -y

    install_pkg \
      ca-certificates \
      curl \
      git \
      build-essential \
      python3 \
      python3-pip \
      python3-venv \
      python3-dev \
      pkg-config \
      flex \
      bison \
      autoconf \
      libfl-dev \
      zlib1g-dev \
      help2man

}

# -----------------------------
# Step 2: Python tooling
# -----------------------------
step_python() {
    echo "=============================="
    echo "🔧 Step 2: Python tooling"
    echo "=============================="

    if command_exists uv; then
        log "uv exists: $(uv --version)"
    else
        log "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
}

# -----------------------------
# Step 3: Bazel
# -----------------------------
USE_VERSION="7.4.1"
MIRROR="https://mirrors.huaweicloud.com/bazel/"

install_bazelisk() {
    log "Installing bazelisk → $LOCAL_BIN/bazel"

    TMP_BIN=$(mktemp)

    curl -fL \
      https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 \
      -o "$TMP_BIN"

    install -m 0755 "$TMP_BIN" "$LOCAL_BIN/bazel"

    rm -f "$TMP_BIN"
}

fix_bazel_env() {
    export BAZELISK_BASE_URL=$MIRROR
    export USE_BAZEL_VERSION=$USE_VERSION

    if [ -n "$CI" ]; then return; fi

    if ! grep -q "^export BAZELISK_BASE_URL=" "$SHELL_RC" 2>/dev/null; then
        echo "export BAZELISK_BASE_URL=$MIRROR" >> "$SHELL_RC"
    fi

    if ! grep -q "^export USE_BAZEL_VERSION=" "$SHELL_RC" 2>/dev/null; then
        echo "export USE_BAZEL_VERSION=$USE_VERSION" >> "$SHELL_RC"
    fi
}

step_bazel() {
    echo "=============================="
    echo "🔧 Step 3: Bazel"
    echo "=============================="

    if command_exists bazel; then
        WHICH_BAZEL=$(which bazel)
        log "bazel found: $WHICH_BAZEL"

        if [[ "$WHICH_BAZEL" != "$LOCAL_BIN"* ]]; then
            warn "system bazel detected → install user-local override"
            install_bazelisk
        else
            log "using user-local bazel ✅"
        fi
    else
        log "bazel not found → installing"
        install_bazelisk
    fi

    fix_bazel_env

    if ! bazel --version >/dev/null 2>&1; then
        warn "mirror failed → fallback to official"
        unset BAZELISK_BASE_URL
    fi

    if bazel --version >/dev/null 2>&1; then
        log "✅ bazel ready: $(bazel --version)"
    else
        warn "bazel may download on first run"
    fi
}

# -----------------------------
# Step 4: Verilator ✅新增
# -----------------------------
step_verilator() {
    echo "=============================="
    echo "🔧 Step 4: Verilator"
    echo "=============================="

    if command_exists verilator; then
        WHICH_VERILATOR=$(which verilator)
        log "verilator exists: $WHICH_VERILATOR"

        if [[ "$WHICH_VERILATOR" == "$HOME/.local"* ]]; then
            log "using user-local verilator ✅"
            return
        else
            warn "system verilator detected → keeping existing install"
            return
        fi
    fi

    log "Building Verilator (user-local)..."

    TMP_DIR=$(mktemp -d)
    git clone https://github.com/verilator/verilator.git "$TMP_DIR"

    cd "$TMP_DIR"
    autoconf
    ./configure \
      --prefix="$HOME/.local" \
      --bindir="$HOME/.local/bin"

    make -j$(nproc)
    make install
    cd -

    rm -rf "$TMP_DIR"

    log "✅ Verilator installed"
}

# -----------------------------
# Step 5: Verification
# -----------------------------
step_verify() {
    echo "=============================="
    echo "✅ Verification"
    echo "=============================="

    echo "which bazel: $(which bazel)"
    bazel --version || true

    echo "which verilator: $(which verilator 2>/dev/null || echo 'not found')"
    verilator --version || true

    echo "uv: $(uv --version 2>/dev/null || echo 'missing')"
    python3 --version

    echo "=============================="
    echo "🎉 All Done!"
    echo "=============================="
}

# -----------------------------
# Main
# -----------------------------
main() {
    ensure_local_bin_in_path
    step_base
    step_python
    step_bazel
    step_verilator
    step_verify
}

main "$@"
``
