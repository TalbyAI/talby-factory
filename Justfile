set shell := ["bash", "-cu"]

default:
	@just --list

# Run bounded Layer 1 diagnostics.
doctor:
	@pnpm doctor