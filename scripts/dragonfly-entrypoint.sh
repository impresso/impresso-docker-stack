#!/bin/sh
set -e

TIERING_ARGS=""

# Detect if the host is a Mac by checking for the internal Mac host mapping
if grep -qi "apple" /proc/cpuinfo 2>/dev/null || grep -qi "apple" /sys/devices/virtual/dmi/id/product_name 2>/dev/null; then
    echo "Running on macOS — io_uring not available — running without tiered storage"
# If not a Mac, proceed with the Linux kernel parameter check
elif [ "$(cat /proc/sys/kernel/io_uring_disabled 2>/dev/null)" = "0" ]; then
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
