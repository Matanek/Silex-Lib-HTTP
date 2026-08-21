# HTTP for Silex

`HTTP` provides a bounded HTTP/1.1 message model and codec. `HTTP.Client`
sends requests, while `HTTP.Server` listens and serves synchronous handlers.
The format of a response body remains independent: pass its UTF-8 text to
`JSON.parse`, `HTML.parse`, `YAML.parse` or another package.

## Client

```sx
use HTTP.Client
use JSON

var response = try Client.get("https://example.com/api")
let data = JSON.parse(try response.text())
```

`Client.Options` controls read/write timeouts and `HTTP.Limits`. The client
sets `Host`, `User-Agent`, `Content-Length` and `Connection: close` when it
owns those framing decisions. Redirect following and content compression are
not implicit in version 0.1.

## Server

```sx
use HTTP
use HTTP.Server

func handle(request:@HTTP.Request) HTTP.Response {
    if request.target() == "/health" {
        return HTTP.Response.text(200, "{\"status\":\"ok\"}", "application/json")
    }
    return HTTP.Response.text(404, "Not found")
}

var server = try Server.listen("127.0.0.1", 8080)
try server.serve(handle)
```

`serve_once` handles one connection and is useful for controlled applications
and tests. `serve` repeats that synchronous operation. Version 0.1 deliberately
does not claim concurrent or event-driven serving; `STD.Threading.Executor`
is a finite CPU-work executor rather than an I/O scheduler.

## Framing and limits

The codec accepts HTTP/1.1 requests, HTTP/1.0 or HTTP/1.1 responses,
`Content-Length`, chunked transfer coding and close-delimited response bodies.
It rejects conflicting framing, invalid field names, bare-LF lines, unsupported
transfer codings and configured header/body limit violations. Outgoing messages
use `Content-Length` and close the connection after one exchange.

`Request.set_text`, `Response.text` and their `text()` projections use UTF-8.
Raw byte bodies remain available for other media types.

## HTTPS

`HTTP.Client` uses `STD.Network.TLS` for `https` URLs. The macOS ARM64 provider
verifies both the certificate chain and requested host name against the system
trust store. Targets without a certificate-verifying TLS provider return a
structured `secure_transport` error; HTTPS never falls back to cleartext.

## Development

```text
silex link .
silex test "$PWD/Tests"
silex run Examples/Server.sx
silex run Examples/Client.sx
```
