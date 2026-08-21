#!/bin/zsh
set -euo pipefail

workspace="${0:A:h:h:h:h}"
log_file="/private/tmp/silex-http-streaming-server.log"
client_log="/private/tmp/silex-http-streaming-client.log"
server_binary="/private/tmp/silex-http-streaming-server"
client_binary="/private/tmp/silex-http-streaming-client"
probe_binary="/private/tmp/silex-http-network-client"
port=$((20000 + RANDOM % 20000))

cd "$workspace"
silex compile Packages/HTTP/Examples/StreamingServer.sx -o "$server_binary"
silex compile Packages/HTTP/Examples/StreamingClient.sx -o "$client_binary"
silex compile Packages/HTTP/Tests/NetworkClient.sx -o "$probe_binary"

"$server_binary" "$port" >"$log_file" 2>&1 &
server_pid=$!

cleanup() {
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

ready=0
for attempt in {1..100}; do
    if "$client_binary" "$port" >"$client_log" 2>&1; then
        ready=1
        break
    fi
    if ! kill -0 "$server_pid" 2>/dev/null; then
        cat "$log_file"
        exit 1
    fi
    sleep 0.05
done
if [[ "$ready" != "1" ]]; then
    cat "$log_file"
    exit 1
fi

cat "$client_log"
"$probe_binary" "$port"
