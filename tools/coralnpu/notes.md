# 方式一：
tools/coralnpu/run_upstream_smoke.sh \
  --repository-cache /hdd_8T/michael/bazel-cache/coralnpu-repo-cache \
  --distdir /hdd_8T/michael/bazel-cache/coralnpu-distdir \
  --disk-cache /hdd_8T/michael/bazel-cache/coralnpu-disk-cache \
  --bazel-flag=--experimental_repository_cache_hardlinks

# 方式二：
export OPEN_NPUX_CORALNPU_REPOSITORY_CACHE=/hdd_8T/michael/bazel-cache/coralnpu-repo-cache
export OPEN_NPUX_CORALNPU_DISTDIR=/hdd_8T/michael/bazel-cache/coralnpu-distdir
export OPEN_NPUX_CORALNPU_DISK_CACHE=/hdd_8T/michael/bazel-cache/coralnpu-disk-cache

export BAZELISK_BASE_URL=https://mirrors.huaweicloud.com/bazel/

export USE_BAZEL_VERSION=7.4.1



mkdir -p thirdparty

git clone https://github.com/google-coral/coralnpu.git thirdparty/coralnpu
git -C thirdparty/coralnpu switch --detach \
  406540cc7d3c7e885ba155a5ee11909d3cb5ee01

git clone https://github.com/gem5/gem5.git thirdparty/gem5
git -C thirdparty/gem5 switch --detach \
  c8222cc67a399bfc01e8658dd14b30d5bfd634f9

git -C thirdparty/coralnpu status --short --branch
git -C thirdparty/gem5 status --short --branch
