#!/usr/bin/env bash
# Dell battery charge mode + thresholds (dell_laptop sysfs). Stored in BIOS, persists across reboots.
# Firmware limits: start 50-95, stop 55-100, stop >= start + 5.
set -euo pipefail

B=/sys/class/power_supply/BAT0

case "${1:-}" in
  --custom) mode=Custom start=${2:-80} stop=${3:-85} ;; # default: hold near 85; firmware needs a 5% gap
  --normal) mode=Fast   start=50 stop=90 ;; # original state, 2026-09-14
  *) echo "usage: ${0##*/} --custom [START STOP]|--normal" >&2; exit 1 ;;
esac

[[ $start =~ ^[0-9]+$ && $stop =~ ^[0-9]+$ ]] && (( start >= 50 && start <= 95 && stop <= 100 && stop >= start + 5 )) \
  || { echo "invalid limits: start=$start stop=$stop" >&2; exit 1; }

if (( EUID )); then [[ -t 0 ]] && exec sudo "$0" "$@"; exec pkexec "$(realpath "$0")" "$@"; fi

# Raise stop first so every intermediate write keeps the 5% gap.
echo 100    > $B/charge_control_end_threshold
echo $start > $B/charge_control_start_threshold
echo $stop  > $B/charge_control_end_threshold
echo $mode  > $B/charge_types

echo "$(grep -o '\[.*\]' $B/charge_types) $(<$B/charge_control_start_threshold)-$(<$B/charge_control_end_threshold)%"
