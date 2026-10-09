#!/bin/sh
# Memory and CPU of the running Yap (and Wispr Flow, if it's running), sampled every 5 s for
# SECONDS (default 60). Memory is the physical footprint, what Activity Monitor shows. Prints JSON.
secs=${1:-60}
footprint_mb() { # total for every process named $1
  total=0
  for pid in $(pgrep -x "$1"); do
    kb=$(footprint -p "$pid" 2>/dev/null | awk '/phys_footprint:/ {v=$2; u=$3} END {if (u=="GB") v*=1048576; else if (u=="MB") v*=1024; print int(v)}')
    total=$((total + ${kb:-0}))
  done
  [ "$total" -gt 0 ] && echo $((total / 1024))
}
cpu_avg() {
  pids=$(pgrep -x "$1" | paste -sd, -); [ -z "$pids" ] && return
  i=0; sum=0
  while [ $i -lt $((secs / 5)) ]; do
    s=$(ps -o %cpu= -p "$pids" | awk '{t+=$1} END {print t}'); sum=$(echo "$sum + $s" | bc); i=$((i + 1)); sleep 5
  done
  echo "scale=1; $sum / $i" | bc
}
yap_cpu=$(cpu_avg Yap)
printf '{"yap_mb":%s,"yap_cpu":%s,"wispr_mb":%s}\n' "$(footprint_mb Yap || echo null)" "${yap_cpu:-null}" "$(footprint_mb 'Wispr Flow' || echo null)"
