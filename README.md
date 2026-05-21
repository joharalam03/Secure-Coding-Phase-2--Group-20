# Secure-Coding-Phase-2--Group-20

URL to version control repository: https://github.com/joharalam03/Secure-Coding-Phase-2--Group-20

### `make reproduce`
This target builds the `bun_parser` in the `target/` directory, generates all crafted, property-based and memory test files, and runs them against the parser. Output is written to the `results/` directory, and clearly indicates which tests trigger a flaw and which pass.

The full test pipeline consists of: (1) reproduction tests (including property-based tests) that verify known parsing flaws, (2) compiler hardening and sanitizer builds (AddressSanitizer and UndefinedBehaviorSanitizer), (3) AFL++ fuzzing summary reporting, and (4) memory stress testing. Results and logs for each stage are written to the `results/` directory.

Sanitizer and reproduction outputs may include ANSI colour codes and informational `[INFO]` / `[REPRODUCED]` tags. These are expected and help distinguish confirmed flaws from normal execution. Warnings from `make clean` (e.g. missing files during cleanup) are harmless and do not affect correctness or build integrity.

The submitted `target/` directory is intentionally empty, in accordance with the project specifications. It is expected that the empty `target` directory is replaced/filled with the provided `group-23` codebase so that the `bun_parser` can be built successfully.
 

### `make clear`
This target deletes all generated test files and results (`results/`, `tests/fixtures/valid/crafted`, `tests/fixtures/invalid/crafted`, `tests/fixtures/property`, `tests/fixtures/memory` ) to reset the environment. Lecturer-supplied sample files are preserved.
