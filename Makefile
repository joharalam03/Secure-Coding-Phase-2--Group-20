# Running make reproduce must execute all of your test cases
# against the target parser and produce output 
# clearly indicating which tests trigger a flaw and which do not

GENERATORS = tests/generators/bunfile_generator.py

.PHONY: generate_crafted
generate_crafted:
	@echo "Ensuring crafted directories exist..."
	@mkdir -p tests/fixtures/valid/crafted
	@mkdir -p tests/fixtures/invalid/crafted

	@echo "Generating crafted fixtures..."
	@python3 $(GENERATORS) --out tests/fixtures/valid/crafted/reserved_nonzero.bun --reserved 42
	
	@python3 $(GENERATORS) --out tests/fixtures/invalid/crafted/rle_bad_uncompressed.bun --compression rle --asset-payload "AAAA" --uncompressed-size 10

	@python3 $(GENERATORS) --out tests/fixtures/invalid/crafted/uncompressed_bad_size.bun --compression none --uncompressed-size 9999

	@python3 $(GENERATORS) --out tests/fixtures/invalid/crafted/bad_align_single_asset.bun --asset-payload "AAAAA" --force-misalignment

	@python3 $(GENERATORS) --out tests/fixtures/invalid/crafted/bad_align_multi_asset.bun --asset-payload "AAAAA" --compression rle --asset-count 4 --force-misalignment

	@python3 $(GENERATORS) \
		--out tests/fixtures/invalid/crafted/bad_align_data_section.bun \
		--asset-payload "AAAA" \
		--compression rle \
		--asset-count 5

	@python3 tests/generators/patch_data_section.py tests/fixtures/invalid/crafted/bad_align_data_section.bun

	@python3 tests/generators/partial_invalid_generator.py

.PHONY: build
build: 
	@echo "Building target source code..."
	@cd target && $(MAKE) || { echo "Build failed"; exit 1; }

.PHONY: reproduce
reproduce: build generate_crafted
	@mkdir -p results

	@echo "=================================================="
	@echo "Running reproduction pipeline"
	@echo "=================================================="

	@echo ""
	@echo "========================================"
	@echo "[1/4] Running parser reproduction tests..."
	@echo "========================================"
	@bash ./tests/scripts/run_all.sh

	@echo ""
	@echo "========================================"
	@echo "[2/4] Running sanitizer analysis..."
	@echo "========================================"
	@bash ./tests/scripts/run_sanitized.sh

	@echo ""
	@echo "========================================"
	@echo "[3/4] Writing AFL fuzzing summary..."
	@echo "========================================"
	@bash ./tests/scripts/run_fuzz_summary.sh

	@echo ""
	@echo "========================================"
	@echo "[4/4] Running memory handling tests..."
	@echo "========================================"
	@bash ./tests/scripts/run_memory_tests.sh

	@echo ""
	@echo "=================================================="
	@echo "Detailed logs written to results/"
	@echo "=================================================="

.PHONY: clear
clear:
	@echo "Deleting all generated directories..."
	@echo "Removing results folder and contents..."
	rm -rf results

	@echo "Removing crafted/generated directories and contents..."
	rm -rf tests/fixtures/valid/crafted
	rm -rf tests/fixtures/invalid/crafted
	rm -rf tests/fixtures/property
	rm -rf tests/fixtures/memory

	@echo "All generated directories removed. Lecturer samples preserved."
	@echo "Clean complete."

		