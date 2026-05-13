# TODO: make a reproduce target 

# Running make reproduce must execute all of your test cases
# against the target parser and produce output 
# clearly indicating which tests trigger a flaw and which do not

GENERATORS = tests/generators/bunfile_generator.py

.PHONY: generate_crafted
generate_crafted:
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



.PHONY: reproduce
reproduce: generate_crafted
	@echo "Running all bun_parser tests..."
	bash ./tests/scripts/run_all.sh


.PHONY: clear

clear:
	@echo "Cleaning reproduction artefacts..."

	# Remove generated logs/results
	rm -rf results/*

	# Remove all crafted test outputs (keep structure)
	rm -f tests/fixtures/valid/crafted/*.bun
	rm -f tests/fixtures/invalid/crafted/*.bun

	# Safety: DO NOT remove lecturer samples
	@echo "Preserving lecturer sample files"
	@echo "Clean complete."