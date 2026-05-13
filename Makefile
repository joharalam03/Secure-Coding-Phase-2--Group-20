# TODO: make a reproduce target 

# Running make reproduce must execute all of your test cases
# against the target parser and produce output 
# clearly indicating which tests trigger a flaw and which do not

reproduce:
	@echo "Running all bun_parser tests..."
	bash ./tests/scripts/run_all.sh