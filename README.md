# HTTP for Silex

`HTTP` provides a bounded HTTP/1.1 model, reusable client and application server. Body
formats remain independent: pass UTF-8 text to `JSON.parse`, `HTML.parse`,
`YAML.parse` or another package instead of coupling those packages to HTTP.

## Client requests

```sx
use HTTP.Client
use JSON

var response = try Client.get("https://example.com/api?limit=10")
try response.require_success()
let data = JSON.parse(try response.text())
```

`get`, `head`, `delete`, `post`, `put` and `patch` cover common requests.
`Client.send` accepts a fully configured `HTTP.Request` when headers or raw
bytes need to be controlled directly.

The default client follows at most ten `301`, `302`, `303`, `307` or `308`
responses. Relative `Location` values are resolved, credentials and cookies are
removed when the origin changes, and HTTPS-to-HTTP downgrades are rejected.
Use `Client.default_options().with_redirects(0)` for manual redirect handling.
An insecure downgrade must be enabled explicitly with
`with_insecure_redirects()`.

`Response.is_success()` leaves status policy with the application;
`Response.require_success()` provides the recoverable strict form.

Untrusted values do not need to cross a panic boundary. `Headers.try_append`,
`Headers.try_set`, `Request.try_new` and `Response.try_new` return a structured
`HTTP.Error`. The original constructors and mutators remain available as strict
conveniences for literals and application-owned constants.

## Reusable client sessions

`Client.Session` explicitly owns shared configuration and persistent
connections. Idle connections are pooled by scheme, host and port, then reused
with HTTP/1.1 keep-alive until either peer requests `Connection: close`.

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

`get`, `head`, `delete`, `post`, `put`, `patch`, `send`, `download`,
`send_stream`, `open` and `open_request` are available on a session. Buffered
operations return an `Exchange` containing the response, final URL and ordered
`RedirectHop` history. The original module functions keep returning
`HTTP.Response` or `IncomingResponse` and delegate to a temporary session for
source compatibility.

Default headers never replace request-specific headers. `authenticate_basic`,
`authenticate_bearer` and `clear_authentication` manage the shared
`Authorization` header. Sensitive defaults are not reapplied after a
cross-origin redirect.

Cookies are disabled by default. `enable_cookies()` activates a conservative,
in-memory, host-scoped session jar with `Path`, `Secure` and `Max-Age=0`
handling. It is cleared with the session and does not claim persistent browser
cookie storage or public-suffix/domain-cookie behavior.

An `IncomingResponse` returns its connection to the owning session only after
the body is fully read, copied or discarded. Closing or dropping an unfinished
response closes that connection instead, preventing unread bytes from
poisoning the next request. `Session.close()` is explicit and idempotent; a
late progressive response can finish safely but its connection will then be
closed rather than repooled.

## Time budgets and network policy

Client options expose fluent connect, read, write and total timeouts. The total
deadline is shared by every redirect and checked throughout HTTP parsing and
body transfer, including between bytes from a slow peer. Server options expose
accept, read, write and whole-connection timeouts as well as backlog control.

```sx
let options = Client.default_options()
    .with_read_timeout(5_000)
    .with_total_timeout(20_000)
    .with_public_network_only()
```

`with_public_network_only()` is opt-in so local development remains convenient.
It filters loopback, private, link-local, unspecified and multicast addresses
after DNS resolution. Every redirect is resolved and checked again. HTTPS
connects to the exact approved endpoint while retaining the original hostname
for certificate verification.

Connection timeouts are enforced by the socket boundary on macOS ARM64, Linux
x86-64, Windows x86-64 and Windows ARM64. Read/write socket timeouts and HTTP
total deadlines are enforced independently, so a slow connect, slow peer and
long redirect chain remain separate budgets.

## Proxies

`Client.Proxy.parse("http://proxy.example:8080")` configures an HTTP proxy.
Attach Basic or Bearer proxy authentication to that value, then pass it through
`Client.Options.with_proxy`. Plain HTTP requests use absolute targets; HTTPS
requests establish a `CONNECT` tunnel before certificate-verifying TLS is
opened for the origin. `Proxy-Authorization` is never forwarded to the HTTPS
origin. The optional public-network policy checks both the proxy and every
origin, including redirected destinations.

## URLs and query parameters

`Url.path`, `Url.query`, `Url.query_parameter` and their `Request` equivalents
separate routing from the raw request target. Duplicate parameters remain
available through `query_parameters`.

```sx
let query = HTTP.encode_query([
    HTTP.QueryParameter(name:"search", value:"Silex HTTP"),
    HTTP.QueryParameter(name:"page", value:"2")
])
```

Encoding uses UTF-8 percent escapes. Decoding rejects incomplete escapes and
invalid UTF-8 instead of returning partially decoded text.

## Server

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

For application-level routing, `HTTP.Server.Router` registers handlers by
method and path. `:name` captures one path segment and a final `*name` captures
the remainder. Middleware runs in registration order before a route and in
reverse order after it. Per-route body/header limits, custom error rendering,
and standardized `404`, `405` and `431` responses are built in.

```sx
func show(context:@Server.Context) HTTP.Response {
    if let id = context.parameter("id") { return HTTP.Response.text(200, id) }
    return HTTP.Response.text(400, "missing id")
}

var router = Server.Router()
try router.get("/items/:id", show)
var application = Server.Application(router)
var listener = try Server.listen("127.0.0.1", 8080,
    Server.default_options().with_workers(4))
try application.serve(listener)
```

`serve_once` exposes the error from one controlled connection. Long-running
`serve` loops isolate malformed, prematurely closed and oversized connections;
when possible they send `400`, `413`, `431` or `501` and continue accepting.
They serve successive HTTP/1.1 requests on a persistent connection until a peer
requests closure or a connection deadline expires. `Request.peer()` exposes
the accepted peer endpoint.

`serve_while` checks an application predicate between connections and returns
successfully when it becomes false. It does not interrupt an accept already in
progress; applications needing periodic checks can configure an accept timeout.
`Application.stop()` performs the same graceful transition and marks the current
response `Connection: close`. One worker remains the low-overhead default;
`with_workers` opts into a bounded `STD.Threading.Executor` pool. The server is
threaded rather than event-driven.

## Forms, media types and content coding

`HTTP.Form` parses and writes `application/x-www-form-urlencoded` values.
`HTTP.Media.MediaType` parses `Content-Type`, including quoted parameters and
`charset`; `ContentDisposition` parses form/download metadata and safely builds
attachments. `HTTP.Multipart.MultipartReader` consumes `multipart/form-data`
progressively from any `STD.IO.Reader`, so file parts do not require buffering
the complete request.

`HTTP.ContentCoding.decompress` decodes bounded `gzip` and `deflate` bodies via
`STD.Compression`. `decompress_response` also normalizes the affected response
headers. Decompression is explicit: the client never expands an untrusted body
without an application-selected output limit.

## Streaming bodies

Buffered requests and responses remain the simplest default. For uploads,
`serve_stream` passes a bounded `Server.IncomingBody` to the handler. Its
`read`, `read_all`, `discard` and `finished` operations are valid for the
duration of that handler.

`Client.download` copies a response body directly into any `STD.IO.Writer` and
returns the status and headers with an empty buffered body. `Client.send_stream`
reads an exact, declared number of bytes from any `STD.IO.Reader`. A streaming
upload is not replayed automatically after a redirect because its input may not
be seekable.

`Client.open` and `Client.open_request` instead return a client-owned
`IncomingResponse`. Inspect its status and headers, then call `read`, `read_all`,
`copy_to` or `discard` progressively. A session-owned response returns a clean,
fully consumed connection to its pool; otherwise `close` or `drop` closes it.

For streamed server output, use the three-argument `serve_stream` handler. Its
`ResponseWriter` can `send` a buffered response, `stream` a reader with a known
`Content-Length`, or `stream_chunked` a reader whose length is not known in
advance.

The incoming body and response writer exist only for the duration of the
handler. A writer accepts exactly one response. Fixed and chunked output both
obey the configured body limit and connection deadline.

The buffered, reusable and progressive flows are documented in the client,
server and streaming sections above. The complete streaming client/server pair
used for integration validation lives under `Tests/`.

## Protocol guarantees and limits

The codec accepts HTTP/1.1 requests, HTTP/1.0 or HTTP/1.1 responses,
`Content-Length`, chunked transfer coding and close-delimited response bodies.
It bounds informational responses, headers, trailers and bodies. It requires
exactly one non-empty `Host` header on HTTP/1.1 requests and rejects conflicting
framing, forbidden trailer fields, invalid field names, bare-LF lines, protocol
upgrades and unsupported transfer codings.

Outgoing buffered messages use `Content-Length`; streamed responses may use
chunked transfer coding. Sessions use keep-alive while one-shot operations
close their temporary pool after completion. Content decompression and cookie
storage remain opt-in in version 0.6.

`Request.set_text`, `Response.text` and their `text()` projections use UTF-8.
Raw byte bodies remain available for other media types.

## HTTPS

`HTTP.Client` uses `STD.Network.TLS` for `https` URLs. HTTPS is available when
the active target provides a certificate- and host-verifying TLS provider.
Otherwise the client returns a structured `secure_transport` error and never
falls back to cleartext.

## Development

From the Silex project workspace root:

```text
silex link Packages/HTTP
silex test Packages/HTTP/Tests
Packages/HTTP/Tests/run-network-tests.sh
```
