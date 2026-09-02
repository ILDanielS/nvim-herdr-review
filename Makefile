.PHONY: test fmt lint

test:
	nvim --headless --clean -u tests/minit.lua

fmt:
	stylua lua plugin tests
