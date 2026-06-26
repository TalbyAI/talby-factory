set shell := ["bash", "-cu"]

default:
	@just --list

# Run bounded Layer 1 diagnostics.
doctor:
	@LAYER1_DOCTOR_VIA_JUST=1 pnpm doctor

# Lint supported documentation Markdown files.
check-md:
	@markdownlint-cli2

# Fix auto-correctable issues in supported documentation Markdown files.
fix-md:
	@markdownlint-cli2 --fix

# Gitnexus analyze without stats.
gitnexus-analyze:
	@gitnexus analyze --no-stats
