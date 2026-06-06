#!/usr/bin/env bash
set -e

################################################################################
# Project Setup Script
#
# Version History:
# v0.1 初版 clone + checkout
# v0.2
#   ✅ 增加幂等（已在目标commit则跳过）
#   ✅ 优化fetch行为
################################################################################

echo "=============================="
echo "📦 Project Setup (coralnpu + gem5)"
echo "=============================="

THIRDPARTY_DIR="thirdparty"
mkdir -p "$THIRDPARTY_DIR"

clone_if_needed() {
    URL=$1
    DIR=$2

    if [ ! -d "$DIR" ]; then
        echo "[INFO] Cloning $(basename $DIR)..."
        git clone "$URL" "$DIR"
    else
        echo "[INFO] $(basename $DIR) exists"
    fi
}

checkout_commit() {
    DIR=$1
    COMMIT=$2

    CURRENT=$(git -C "$DIR" rev-parse HEAD 2>/dev/null || echo "none")

    if [ "$CURRENT" = "$COMMIT" ]; then
        echo "[INFO] $(basename $DIR) already at target commit"
        return
    fi

    echo "[INFO] Updating $(basename $DIR)..."
    git -C "$DIR" fetch --all
    git -C "$DIR" switch --detach "$COMMIT"
}

# coralnpu
clone_if_needed https://github.com/google-coral/coralnpu.git \
    "$THIRDPARTY_DIR/coralnpu"

checkout_commit "$THIRDPARTY_DIR/coralnpu" \
    406540cc7d3c7e885ba155a5ee11909d3cb5ee01

# gem5
clone_if_needed https://github.com/gem5/gem5.git \
    "$THIRDPARTY_DIR/gem5"

checkout_commit "$THIRDPARTY_DIR/gem5" \
    c8222cc67a399bfc01e8658dd14b30d5bfd634f9

# verify
echo "=============================="
echo "✅ Repo status"
echo "=============================="

git -C "$THIRDPARTY_DIR/coralnpu" status --short --branch
git -C "$THIRDPARTY_DIR/gem5" status --short --branch

echo "=============================="
echo "🎉 Project Ready"
echo "=============================="
