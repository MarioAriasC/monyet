# Monyet

[Crystal](https://crystal-lang.org/reference/1.2/index.html) implementation of the [Monkey Language](https://monkeylang.org/)

Monyet has a sibling implementation for Kotlin: [monkey.kt](https://github.com/MarioAriasC/monkey.kt)

## Status

The two books ([Writing An Interpreter In Go](https://interpreterbook.com/)
and [Writing A Compiler in Go](https://compilerbook.com/)) are implemented.

## Commands

Before running the command you must have crystal and shards installed on your machine

| Script          | Description                                                                                                        |
|-----------------|--------------------------------------------------------------------------------------------------------------------|
| `tests.sh`      | Run all the tests                                                                                                  |
| `checks.sh`     | Run format tool and ameba checks                                                                                   |
| `build.sh`      | Release build                                                                                                      |
| `benchmarks.sh` | Run the classic monkey benchmark (fibonacci(35)), requires one command (`--eval`,`--eval-fast`,`--vm`,`--vm-fast`) |
| `repl.sh`       | Run the Monyet REPL                                                                                                |