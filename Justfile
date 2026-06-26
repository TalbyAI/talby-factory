set shell := ["bash", "-cu"]

default:
	@just --list

# Run bounded Layer 1 diagnostics.
doctor:
	@LAYER1_DOCTOR_VIA_JUST=1 pnpm doctor

# Gitnexus analyze without stats.
gitnexus-analyze:
	@gitnexus analyze --no-stats
