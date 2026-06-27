FROM mcr.microsoft.com/devcontainers/dotnet:2-10.0-noble

ENV PNPM_HOME=/usr/local/share/pnpm
ENV PNPM_BIN_DIR=/usr/local/share/pnpm/bin
ENV PNPM_GLOBAL_DIR=/usr/local/share/pnpm-global
ENV DOTNET_TOOLS_DIR=/usr/local/share/dotnet-tools
ENV PATH=${PNPM_HOME}:${PNPM_BIN_DIR}:${DOTNET_TOOLS_DIR}:${PATH}

ARG PNPM_VERSION=11.9.0
ARG NODE_VERSION=24.18.0
ARG OPENCODE_VERSION=1.17.10
ARG CODEX_VERSION=0.142.2
ARG COPILOT_VERSION=1.0.63
ARG CONTEXT_MODE_VERSION=1.0.166
ARG GITNEXUS_VERSION=1.6.8
ARG GH_VERSION=2.95.0
ARG GENTLE_AI_VERSION=1.42.0
ARG ENGRAM_VERSION=1.17.0
ARG GGA_VERSION=2.8.1
ARG MARKDOWNLINT_CLI2_VERSION=0.22.1
ARG ASPIRE_VERSION=13.4.5
ARG CSHARPIER_VERSION=1.3.0
ARG BIOME_VERSION=2.5.1
ARG OPENSRC_VERSION=0.7.3
ARG SKILLS_VERSION=1.5.13

# Install base OS packages and create shared tool directories.
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gnupg just lsb-release ripgrep xz-utils \
    && mkdir -p "$PNPM_HOME" "$PNPM_BIN_DIR" "$PNPM_GLOBAL_DIR" "$DOTNET_TOOLS_DIR" \
    && rm -rf /var/lib/apt/lists/*

# Add the Microsoft apt source and install Azure CLI.
RUN mkdir -p /etc/apt/keyrings \
    && curl --fail --silent --show-error --location https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
    && chmod go+r /etc/apt/keyrings/microsoft.gpg \
    && printf 'Types: deb\nURIs: https://packages.microsoft.com/repos/azure-cli/\nSuites: %s\nComponents: main\nArchitectures: %s\nSigned-by: /etc/apt/keyrings/microsoft.gpg\n' \
        "$(lsb_release -cs)" "$(dpkg --print-architecture)" > /etc/apt/sources.list.d/azure-cli.sources \
    && apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends azure-cli \
    && rm -rf /var/lib/apt/lists/*

# Install pinned Node.js and GitHub CLI binaries for the current architecture.
RUN mkdir -p /tmp/gh-cli \
    && case "$(dpkg --print-architecture)" in \
        amd64) node_arch='x64' ;; \
        arm64) node_arch='arm64' ;; \
        *) echo "Unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
    && curl --fail --silent --show-error --location \
        "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
        -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner \
    && curl --fail --silent --show-error --location \
        "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_$(dpkg --print-architecture).tar.gz" \
        -o /tmp/gh-cli/gh.tar.gz \
    && tar -xzf /tmp/gh-cli/gh.tar.gz -C /tmp/gh-cli --strip-components=1 \
    && install -m 0755 /tmp/gh-cli/bin/gh /usr/local/bin/gh \
    && rm -rf /tmp/gh-cli /tmp/node.tar.xz

# Install pinned Gentle AI ecosystem CLIs.
RUN mkdir -p /tmp/gentle-ai /tmp/engram /tmp/gga /usr/local/lib/gga/bin /usr/local/lib/gga/lib \
    && curl --fail --silent --show-error --location \
        "https://github.com/Gentleman-Programming/gentle-ai/releases/download/v${GENTLE_AI_VERSION}/gentle-ai_${GENTLE_AI_VERSION}_linux_$(dpkg --print-architecture).tar.gz" \
        -o /tmp/gentle-ai/gentle-ai.tar.gz \
    && tar -xzf /tmp/gentle-ai/gentle-ai.tar.gz -C /tmp/gentle-ai \
    && install -m 0755 /tmp/gentle-ai/gentle-ai /usr/local/bin/gentle-ai \
    && curl --fail --silent --show-error --location \
        "https://github.com/Gentleman-Programming/engram/releases/download/v${ENGRAM_VERSION}/engram_${ENGRAM_VERSION}_linux_$(dpkg --print-architecture).tar.gz" \
        -o /tmp/engram/engram.tar.gz \
    && tar -xzf /tmp/engram/engram.tar.gz -C /tmp/engram \
    && install -m 0755 /tmp/engram/engram /usr/local/bin/engram \
    && curl --fail --silent --show-error --location \
        "https://github.com/Gentleman-Programming/gentleman-guardian-angel/archive/refs/tags/v${GGA_VERSION}.tar.gz" \
        -o /tmp/gga/gga.tar.gz \
    && tar -xzf /tmp/gga/gga.tar.gz -C /tmp/gga \
    && install -m 0755 /tmp/gga/gentleman-guardian-angel-${GGA_VERSION}/bin/gga /usr/local/lib/gga/bin/gga \
    && install -m 0755 /tmp/gga/gentleman-guardian-angel-${GGA_VERSION}/lib/providers.sh /usr/local/lib/gga/lib/providers.sh \
    && install -m 0755 /tmp/gga/gentleman-guardian-angel-${GGA_VERSION}/lib/cache.sh /usr/local/lib/gga/lib/cache.sh \
    && install -m 0755 /tmp/gga/gentleman-guardian-angel-${GGA_VERSION}/lib/pr_mode.sh /usr/local/lib/gga/lib/pr_mode.sh \
    && sed -i 's|^VERSION="${GGA_VERSION:-dev}"$|VERSION="'"${GGA_VERSION}"'"|' /usr/local/lib/gga/bin/gga \
    && sed -i 's|^LIB_DIR=.*$|LIB_DIR="/usr/local/lib/gga/lib"|' /usr/local/lib/gga/bin/gga \
    && install -m 0755 /usr/local/lib/gga/bin/gga /usr/local/bin/gga \
    && rm -rf /tmp/gentle-ai /tmp/engram /tmp/gga

# Install global npm and pnpm developer CLIs.
RUN npm install --global "pnpm@${PNPM_VERSION}" "opencode-ai@${OPENCODE_VERSION}" "@github/copilot@${COPILOT_VERSION}" \
    && pnpm config set global-bin-dir "$PNPM_BIN_DIR" \
    && pnpm config set global-dir "$PNPM_GLOBAL_DIR" \
    && pnpm add --global \
        --allow-build=gitnexus \
        --allow-build=@ladybugdb/core \
        --allow-build=tree-sitter \
        "@openai/codex@${CODEX_VERSION}" \
        "context-mode@${CONTEXT_MODE_VERSION}" \
        "gitnexus@${GITNEXUS_VERSION}" \
        "markdownlint-cli2@${MARKDOWNLINT_CLI2_VERSION}" \
        "@biomejs/biome@${BIOME_VERSION}" \
        "opensrc@${OPENSRC_VERSION}" \
        "skills@${SKILLS_VERSION}"

# Install dotnet tools and prepare the vscode user's global tool configuration.
RUN dotnet tool install --tool-path "$DOTNET_TOOLS_DIR" aspire.cli --version "$ASPIRE_VERSION" \
    && dotnet tool install --tool-path "$DOTNET_TOOLS_DIR" csharpier --version "$CSHARPIER_VERSION" \
    && mkdir -p /home/vscode/.config/pnpm /home/vscode/.codex /home/vscode/.copilot /home/vscode/.opensrc /home/vscode/.agents/skills \
    && printf 'globalBinDir: %s\nglobalDir: %s\n' "$PNPM_BIN_DIR" "$PNPM_GLOBAL_DIR" > /home/vscode/.config/pnpm/config.yaml \
    && chown -R vscode:vscode "$PNPM_HOME" "$PNPM_GLOBAL_DIR" "$DOTNET_TOOLS_DIR" /home/vscode/.codex /home/vscode/.copilot /home/vscode/.opensrc /home/vscode/.agents \
    && chown -R vscode:vscode /home/vscode/.config/pnpm
