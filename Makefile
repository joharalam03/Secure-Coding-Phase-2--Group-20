# TODO: make a reproduce target 

# Running make reproduce must execute all of your test cases
# against the target parser and produce output 
# clearly indicating which tests trigger a flaw and which do not

GENERATORS = tests/generators/bunfile_generator.py

.PHONY: generate_crafted
generate_crafted:
	# reserved field non-zero
	python3 $(GENERATORS) --out tests/fixtures/valid/crafted/reserved_nonzero.bun --reserved 42
	
	# RLE uncompressed_size mismatch (priority #2)
	python3 $(GENERATORS) --out tests/fixtures/invalid/crafted/rle_bad_uncompressed.bun --compression rle --asset-payload "AAAA" --uncompressed-size 10

.PHONY: reproduce
reproduce: generate_crafted
	@echo "Running all bun_parser tests..."
	bash ./tests/scripts/run_all.sh