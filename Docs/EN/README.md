# HTTP

`HTTP` provides a bounded HTTP/1.1 model, reusable client sessions, and an
application server. Transport remains independent from body formats: pass
UTF-8 text to `JSON.parse`, `HTML.parse`, `YAML.parse`, or another package.

## Client requests

```sx
use HTTP.Client
use JSON

var response = try Client.get("https://example.com/api?limit=10")
try response.require_success()
let data = JSON.parse(try response.text())
```

The `get`, `head`, `delete`, `post`, `put`, and `patch` operations cover common
requests. `Client.send` accepts a configured `HTTP.Request`.
`Response.is_success()` leaves status policy with the application;
`Response.require_success()` provides the strict recoverable form.

By default, the client follows at most ten redirects. It resolves relative
`Location` values, removes credentials and cookies when the origin changes,
and rejects HTTPS-to-HTTP downgrades.

## Reusable sessions

A `Client.Session` owns its configuration and connection pool.

```sx
var session = try Client.Session.create(
    Client.default_options().with_maximum_idle_connections_per_origin(4)
)
try session.set_default_header("Accept", "application/json")
try session.authenticate_bearer(token)
session.enable_cookies()

var exchange = try session.get("https://example.com/api")
print(exchange.final_url.text())
print(exchange.redirects.count())

try session.close()
```

Request-specific headers take precedence over defaults. Cookies are disabled
by default; the optional jar is in-memory and host-scoped. A progressive
response returns its connection to the pool only after its body is fully read,
copied, or discarded.

## Timeouts, network policy, and proxies

Client options distinguish connect, read, write, and total timeouts. The total
budget is shared by redirects. `with_public_network_only()` rejects loopback,
private, link-local, unspecified, and multicast addresses after DNS resolution,
then repeats the check on every redirect.

```sx
let options = Client.default_options()
    .with_read_timeout(5_000)
    .with_total_timeout(20_000)
    .with_public_network_only()
```

`Client.Proxy.parse` configures an HTTP proxy with Basic or Bearer
authentication. HTTP uses absolute targets; HTTPS establishes a `CONNECT`
tunnel before TLS. `Proxy-Authorization` is never forwarded to the HTTPS
origin.

## URLs, forms, and content

`Url.path`, `Url.query`, and `Url.query_parameter` separate routing from the raw
target. Parameter encoding uses UTF-8 escapes, and decoding rejects invalid
sequences.

```sx
let query = HTTP.encode_query([
    HTTP.QueryParameter(name:"search", value:"Silex HTTP"),
    HTTP.QueryParameter(name:"page", value:"2")
])
```

`HTTP.Form` handles URL-encoded forms. `HTTP.Media` parses content types and
dispositions. `HTTP.Multipart.MultipartReader` reads progressively from a
`STD.IO.Reader`. `HTTP.ContentCoding` explicitly decompresses `gzip` and
`deflate` with an application-selected limit.

## Server and routing

```sx
use HTTP
use HTTP.Server

func handle(request:@HTTP.Request) HTTP.Response {
    if request.path() == "/health" {
        return HTTP.Response.text(200, "{\"status\":\"ok\"}", "application/json")
    }
    return HTTP.Response.text(404, "Not found")
}

var server = try Server.listen("127.0.0.1", 8080)
try server.serve(handle)
```

`HTTP.Server.Router` maps methods and paths. `:name` captures one segment and a
final `*name` captures the remainder. Middleware runs in registration order
before a route, then in reverse order. Per-route limits and standardized `404`,
`405`, and `431` responses are built in.

`serve_once` exposes the error from one controlled connection. `serve` isolates
invalid connections and keeps accepting. `serve_while` and `Application.stop()`
provide graceful shutdown. `with_workers` enables a bounded
`STD.Threading.Executor` pool.

## Streaming and protocol guarantees

`Client.download` copies into a `STD.IO.Writer`. `send_stream` sends an exact
byte count from a `STD.IO.Reader`. `open` and `open_request` return a
progressively readable `IncomingResponse`. On the server, `IncomingBody` and
`ResponseWriter` handle bounded bodies of known length or with chunked encoding.

The codec accepts HTTP/1.1 requests, HTTP/1.0 or HTTP/1.1 responses,
`Content-Length`, chunked transfer coding, and close-delimited responses. It
bounds headers, trailers, and bodies, and rejects ambiguous framing, bare-LF
lines, upgrades, and unsupported codings.

HTTPS uses `STD.Network.TLS`. Without a TLS provider that verifies certificate
and host, the client returns a `secure_transport` error and never falls back to
cleartext.

## Development

From the Silex workspace root:

```text
silex link Packages/HTTP
silex test Packages/HTTP/Tests
Packages/HTTP/Tests/run-network-tests.sh
```
