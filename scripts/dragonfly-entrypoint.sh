#!/bin/sh
set -e

TIERING_ARGS=""

# Probe io_uring_setup syscall (425) directly — ENOSYS means not supported,
# any other error (EINVAL etc.) means it exists and tiered storage can work.
if python3 -c "
import ctypes, ctypes.util, errno
libc = ctypes.CDLL(ctypes.util.find_library('c'), use_errno=True)
libc.syscall(425, ctypes.c_uint(1), ctypes.c_void_p(0))
exit(1 if ctypes.get_errno() == errno.ENOSYS else 0)
" 2>/dev/null; then
    echo "io_uring available — enabling tiered storage"
    TIERING_ARGS="--tiered_prefix=/data/tiered"
else
    echo "io_uring not available — running without tiered storage"
fi

# Determine maxmemory: use MAXMEMORY env var, or default to half of available RAM.
# Checks cgroup memory limit (container limit) first, then falls back to /proc/meminfo.
if [ -n "$MAXMEMORY" ]; then
    MAXMEMORY_ARG="$MAXMEMORY"
else
    TOTAL_MEM_MB=$(awk '/MemTotal/ { printf "%d\n", ($2 + 512) / 1024 }' /proc/meminfo)

    MAXMEMORY_MB=$(( (TOTAL_MEM_MB + 1) / 2 ))
    MAXMEMORY_ARG="${MAXMEMORY_MB}mb"
    echo "Total memory: ${TOTAL_MEM_MB}mb, allocating ${MAXMEMORY_MB}mb to dragonfly"
fi

exec dragonfly --logtostderr=false --maxmemory="$MAXMEMORY_ARG" --proactor_threads=4 --dir=/data --dbfilename=dump --snapshot_cron="0 * * * *" --default_lua_flags=allow-undeclared-keys $TIERING_ARGS
