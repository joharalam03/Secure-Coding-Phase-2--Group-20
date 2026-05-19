# Secure-Coding-Phase-2--Group-20

URL to version control repository: https://github.com/joharalam03/Secure-Coding-Phase-2--Group-20

### `make reproduce`
This target builds the `bun_parser` in the `target` directory, generates all crafted and property-based test files, and runs them against the parser. Output is written to the `results/` directory, and clearly indicates which tests trigger a flaw and which pass.

### `make clear`
This target deletes all generated test files and results (`results/`, `tests/fixtures/valid/crafted`, `tests/fixtures/invalid/crafted`, `tests/fixtures/property`) to reset the environment. Lecturer-supplied sample files are preserved.