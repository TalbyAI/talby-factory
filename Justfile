set shell := ["bash", "-cu"]

# Checks the health of the development environment
doctor:
	bash .devcontainer/doctor.sh

# Lints all markdown files in the repository
lint-md:
	markdownlint-cli2 "**/*.md"

# Serves container-local HTML files for opening in the host browser
open-html root file host='127.0.0.1' port='8123':
	node .devcontainer/serve-container-html.js --root '{{root}}' --file '{{file}}' --host '{{host}}' --port '{{port}}'