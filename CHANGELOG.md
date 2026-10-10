# Changelog

## [Unreleased]

- Adopts one `Result` declaration: an ordinary call returns the value or
  stops the program on failure; `try call()` keeps the `Result`. Existing calls
  storing results and propagating failures are made explicit. This revision
  requires the development toolchain with these `try` semantics; publication
  must coordinate compiler and package versions.
  Recoverable `try_*` variants and direct wrappers with the same signature
  converge under the ordinary name. Boolean, optional, and native variants
  retain their contracts.
