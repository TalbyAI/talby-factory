set shell := ["bash", "-cu"]

default:
	@just --list

# Run bounded Layer 1 diagnostics.
doctor:
	@LAYER1_DOCTOR_VIA_JUST=1 pnpm doctor