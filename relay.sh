#!/usr/bin/env bash
# Runs in the host network: exposes each host-loopback port given as an argument as a unix socket for the Claude container.
set -euo pipefail

for port; do
  socat "UNIX-LISTEN:/run/claude-relay/$port.sock,fork,unlink-early" "TCP:127.0.0.1:$port" &
done
wait
