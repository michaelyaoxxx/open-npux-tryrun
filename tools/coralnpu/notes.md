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
