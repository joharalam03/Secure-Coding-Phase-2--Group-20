# Running make reproduce must execute all of your test cases
# against the target parser and produce output 
# clearly indicating which tests trigger a flaw and which do not

GENERATORS = tests/generators/bunfile_generator.py

.PHONY: generate_crafted
generate_crafted:
	@echo "Ensuring crafted directories exist..."
	mkdir -p tests/fixtures/valid/crafted
	mkdir -p tests/fixtures/invalid/crafted

	# reserved field non-zero
	python3 $(GENERATORS) --out tests/fixtures/valid/crafted/reserved_nonzero.bun --reserved 42
	
	# RLE uncompressed_size mismatch 
	python3 $(GENERATORS) --out tests/fixtures/invalid/crafted/rle_bad_uncompressed.bun --compression rle --asset-payload "AAAA" --uncompressed-size 10

	# set uncompressed size != 0 when compression==0
	python3 $(GENERATORS) --out tests/fixtures/invalid/crafted/uncompressed_bad_size.bun --compression none --uncompressed-size 9999

	# Alignment test single asset (safe controlled corruption)
	python3 $(GENERATORS) --out tests/fixtures/invalid/crafted/bad_align_single_asset.bun --asset-payload "AAAAA" --force-misalignment
	# Alignment test multi-asset (safe controlled corruption)
	python3 $(GENERATORS) --out tests/fixtures/invalid/crafted/bad_align_multi_asset.bun --asset-payload "AAAAA" --compression rle --asset-count 4 --force-misalignment

	python3 tests/generators/partial_string_attack.py

.PHONY: build
build: 
	@echo "Building target source code..."
	cd target && $(MAKE) || { echo "Build failed"; exit 1; }

.PHONY: reproduce
reproduce: build generate_crafted
	@echo "Setting up directories for test output..."
	# Create results directory
	mkdir -p results

	# Ensure additional test directories exist
	mkdir -p tests/fixtures/hangs
	mkdir -p tests/fixtures/malformed
	mkdir -p tests/fixtures/memory

	@echo "Running all bun_parser tests..."
	bash ./tests/scripts/run_all.sh


.PHONY: clear
clear:
	@echo "Deleting all generated directories..."
	# Remove results folder and contents
	rm -rf results

	# Remove all crafted/generated directories and contents
	rm -rf tests/fixtures/valid/crafted
	rm -rf tests/fixtures/invalid/crafted
	rm -rf tests/fixtures/hangs
	rm -rf tests/fixtures/malformed
	rm -rf tests/fixtures/memory

	@echo "All generated directories removed. Lecturer samples preserved."
	@echo "Clean complete."