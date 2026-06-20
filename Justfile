set shell := ["bash", "-cu"]

# Reports the current Dev Container rebuild status
doctor:
	@echo "Layer 1 doctor is not implemented yet."
	@echo "See .devcontainer/README.md and docs/plans/devcontainer-rebuild-plan.md."
	exit 1

# Lints all markdown files in the repository
lint-md:
	markdownlint-cli2 "**/*.md"