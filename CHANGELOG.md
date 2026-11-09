# Changelog

## [0.7.0] - 2026-11-09

- Adopts one `Result` declaration: an ordinary call returns the value or
  stops the program on failure; `try call()` keeps the `Result`. Existing calls
  storing results and propagating failures are made explicit. This version
  requires Silex 0.48.0 or newer and the coordinated dependency versions.
  Recoverable `try_*` variants and direct wrappers with the same signature
  converge under the ordinary name. Boolean, optional, and native variants
  retain their contracts.
