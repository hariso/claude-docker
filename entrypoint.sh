#!/usr/bin/env bash
# Runs as root: blocks local networks, starts the relay clients, then runs the arguments as CLAUDE_USER without
# capabilities, so the firewall can't be changed from inside.
set -euo pipefail

iptables -A OUTPUT -o lo -j ACCEPT
ip6tables -A OUTPUT -o lo -j ACCEPT

# Docker's embedded DNS forwards to these from this namespace; host(...) entries are forwarded from the host's.
for server in $(sed -n 's/^# ExtServers: \[\(.*\)\]$/\1/p' /etc/resolv.conf); do
  case "$server" in
    host\(*) continue ;;
    *:*) ipt=ip6tables ;;
    *) ipt=iptables ;;
  esac
  for proto in udp tcp; do
    "$ipt" -A OUTPUT -d "$server" -p "$proto" --dport 53 -j ACCEPT
  done
done

for net in 10.0.0.0/8 100.64.0.0/10 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4 $HOST_ADDRS; do
  [[ "$net" == *:* ]] && continue
  iptables -A OUTPUT -d "$net" -j REJECT
done

ip6tables -P OUTPUT DROP

drop=(--reuid="$CLAUDE_USER" --regid="$CLAUDE_USER" --init-groups --inh-caps=-all --bounding-set=-all)

for port in $RELAY_PORTS; do
  setpriv "${drop[@]}" socat "TCP-LISTEN:$port,bind=127.0.0.1,fork,reuseaddr" "UNIX-CONNECT:/run/claude-relay/$port.sock" &
done

exec setpriv "${drop[@]}" "$@"
