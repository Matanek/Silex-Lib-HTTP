#!/bin/zsh
set -euo pipefail

workspace="${0:A:h:h:h:h}"
log_file="/private/tmp/silex-http-streaming-server.log"
client_log="/private/tmp/silex-http-streaming-client.log"
server_binary="/private/tmp/silex-http-streaming-server"
client_binary="/private/tmp/silex-http-streaming-client"
probe_binary="/private/tmp/silex-http-network-client"
proxy_binary="/private/tmp/silex-http-proxy-client"
proxy_log="/private/tmp/silex-http-proxy.log"
port=$((20000 + RANDOM % 20000))
proxy_port=$((40001 + RANDOM % 20000))

cd "$workspace"
silex compile Packages/HTTP/Tests/StreamingServer.sx -o "$server_binary"
silex compile Packages/HTTP/Tests/StreamingClient.sx -o "$client_binary"
silex compile Packages/HTTP/Tests/NetworkClient.sx -o "$probe_binary"
silex compile Packages/HTTP/Tests/ProxyClient.sx -o "$proxy_binary"

"$server_binary" "$port" >"$log_file" 2>&1 &
server_pid=$!
python3 Packages/HTTP/Tests/ProxyServer.py "$proxy_port" >"$proxy_log" 2>&1 &
proxy_pid=$!

cleanup() {
    kill "$server_pid" 2>/dev/null || true
    kill "$proxy_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
    wait "$proxy_pid" 2>/dev/null || true
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

for attempt in {1..100}; do
    if rg -q '^ready$' "$proxy_log"; then break; fi
    if ! kill -0 "$proxy_pid" 2>/dev/null; then
        cat "$proxy_log"
        exit 1
    fi
    sleep 0.05
done
rg -q '^ready$' "$proxy_log"
"$proxy_binary" "$proxy_port"
wait "$proxy_pid"
rg -q '^GET http://example\.test:8080/resource\?value=1 HTTP/1\.1$' "$proxy_log"
rg -q '^CONNECT secure\.example\.test:443 HTTP/1\.1$' "$proxy_log"
[[ "$(rg -c '^Proxy-Authorization: Basic cHJveHktdXNlcjpwcm94eS1wYXNz$' "$proxy_log")" == "2" ]]
echo "proxy request framing and credential isolation verified"
