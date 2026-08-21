# HTTP for Silex

`HTTP` provides a bounded HTTP/1.1 model, client and synchronous server. Body
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

`serve_once` exposes the error from one controlled connection. Long-running
`serve` loops isolate malformed, prematurely closed and oversized connections;
when possible they send `400`, `413`, `431` or `501` and continue accepting.
`Request.peer()` exposes the accepted peer endpoint.

`serve_while` checks an application predicate between connections and returns
successfully when it becomes false. It does not interrupt an accept already in
progress; applications needing periodic checks can configure an accept timeout.
The server remains intentionally synchronous and does not claim event-driven or
concurrent I/O.

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

See `Examples/AdvancedServer.sx` and `Examples/AdvancedClient.sx` for a complete
redirect, query, upload and download flow.

## Protocol guarantees and limits

The codec accepts HTTP/1.1 requests, HTTP/1.0 or HTTP/1.1 responses,
`Content-Length`, chunked transfer coding and close-delimited response bodies.
It bounds informational responses, headers, trailers and bodies. It requires
exactly one non-empty `Host` header on HTTP/1.1 requests and rejects conflicting
framing, forbidden trailer fields, invalid field names, bare-LF lines, protocol
upgrades and unsupported transfer codings.

Outgoing messages currently use `Content-Length` and `Connection: close`.
Connection pooling, automatic content decompression and cookie persistence are
not implicit in version 0.2.

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
silex run Packages/HTTP/Examples/Server.sx
silex run Packages/HTTP/Examples/Client.sx
silex run Packages/HTTP/Examples/AdvancedServer.sx
silex run Packages/HTTP/Examples/AdvancedClient.sx
```
