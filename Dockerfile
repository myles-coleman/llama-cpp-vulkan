# Multi-stage build for llama.cpp with Vulkan support (ARM64)
#
# Builds llama-server and llama-cli with Vulkan GPU acceleration
# for use on ARM64 hosts with AMD GPUs (via Mesa RADV driver).
#
# Usage:
#   docker buildx build --platform linux/arm64 -t llama-cpp-vulkan .

# --- Builder stage ---
FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    cmake \
    git \
    libvulkan-dev \
    glslang-tools \
    glslc \
    spirv-headers \
    libcurl4-openssl-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Clone llama.cpp and build with Vulkan + curl support
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /build/llama.cpp

WORKDIR /build/llama.cpp

RUN cmake -B build \
    -DGGML_VULKAN=1 \
    -DLLAMA_CURL=ON \
    -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --config Release -j$(nproc)

# --- Runtime stage ---
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libvulkan1 \
    mesa-vulkan-drivers \
    libcurl4t64 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy built binaries
COPY --from=builder /build/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server
COPY --from=builder /build/llama.cpp/build/bin/llama-cli /usr/local/bin/llama-cli

# Create non-root user
RUN groupadd -g 1001 llama && \
    useradd -u 1001 -g llama -m llama

USER llama

EXPOSE 8080

ENTRYPOINT ["llama-server"]
