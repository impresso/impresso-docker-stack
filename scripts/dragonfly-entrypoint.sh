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

exec dragonfly --logtostderr --maxmemory=2gb --proactor_threads=4 --dir=/data --dbfilename=dump --snapshot_cron="0 * * * *" --default_lua_flags=allow-undeclared-keys $TIERING_ARGS
