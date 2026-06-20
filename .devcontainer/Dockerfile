FROM mcr.microsoft.com/devcontainers/dotnet:2-10.0-noble

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends just \
    && rm -rf /var/lib/apt/lists/*