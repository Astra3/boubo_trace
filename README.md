# BouboTrace
BouboTrace is a tool that allows you to watch Linux syscalls on x86 as they are called from a program. It can skip to `main` function and it allows you to output the calls into a JSON file.

## Installation
To install, first install [Cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html) and then use `cargo run -r` to build and run in release mode. Use `cargo run -r -- --help` to print help to BouboTrace. Once you run the program once, the built binary file will be available at `target/release/boubo_trace`, you can use that directly as well without using Cargo to run it.

