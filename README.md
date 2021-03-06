# Monyet

[Crystal](https://crystal-lang.org/reference/1.2/index.html) implementation of
the [Monkey Language](https://monkeylang.org/)

Monyet has a sibling implementation for Kotlin: [monkey.kt](https://github.com/MarioAriasC/monkey.kt)

## Status

The two books ([Writing An Interpreter In Go](https://interpreterbook.com/)
and [Writing A Compiler in Go](https://compilerbook.com/)) are implemented.

## Commands

Before running the command you must have crystal and shards installed on your machine

| Script                           | Description                                                                                                          |
|----------------------------------|----------------------------------------------------------------------------------------------------------------------|
| [`tests.sh`](tests.sh)           | Run all the tests                                                                                                    |
| [`checks.sh`](checks.sh)         | Run format tool and ameba checks                                                                                     |
| [`build.sh`](build.sh)           | Release build                                                                                                        |
| [`benchmarks.sh`](benchmarks.sh) | Run the classic monkey benchmark (`fibonacci(35)`), requires one command (`--eval`,`--eval-fast`,`--vm`,`--vm-fast`) |
| [`repl.sh`](repl.sh)             | Run the Monyet REPL                                                                                                  |

## Compiling variants

There are two different implementations for the compiler/VM.

* The default variant, based on `Array(UInt8)` as Bytecode and `OffsetArray` arrays for read operations
* The slices variant, based purely on `Slice(UInt8)`

The slices variant is more idiomatic but the default variant has better performance (around 10%).

To compile with a different variant you can the flag `--define=slice` to your compile or test. Additionally,
both [`build.sh`](build.sh) and [`test.sh`](tests.sh) have lines that you can comment/uncomment to enable different
variants