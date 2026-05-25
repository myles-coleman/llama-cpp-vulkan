# Multi-stage build for llama.cpp with Vulkan support (multi-arch)
#
# Builds llama-server and llama-cli with Vulkan GPU acceleration
# for use on ARM64 or AMD64 hosts with Vulkan-capable GPUs.
#
# Usage:
#   docker buildx build --platform linux/arm64,linux/amd64 -t llama-cpp-vulkan .

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

ARG TARGETARCH
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      CPU_FLAGS="-mcpu=cortex-a76"; \
    else \
      CPU_FLAGS=""; \
    fi && \
    cmake -B build \
      -DGGML_VULKAN=1 \
      -DLLAMA_CURL=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON \
      -DGGML_NATIVE=OFF \
      ${CPU_FLAGS:+-DCMAKE_C_FLAGS="$CPU_FLAGS"} \
      ${CPU_FLAGS:+-DCMAKE_CXX_FLAGS="$CPU_FLAGS"} \
    && cmake --build build --config Release -j$(nproc) \
    && mkdir -p /build/llama.cpp/build/dist/lib \
    && find /build/llama.cpp/build -name '*.so*' -exec cp -P {} /build/llama.cpp/build/dist/lib/ \;

# --- Runtime stage ---
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libvulkan1 \
    mesa-vulkan-drivers \
    libcurl4t64 \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy built binaries and shared libraries
COPY --from=builder /build/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server
COPY --from=builder /build/llama.cpp/build/bin/llama-cli /usr/local/bin/llama-cli
COPY --from=builder /build/llama.cpp/build/dist/lib/ /usr/local/lib/
RUN ldconfig && \
    echo "=== Checking llama-server deps ===" && \
    ldd /usr/local/bin/llama-server && \
    ! ldd /usr/local/bin/llama-server | grep "not found" && \
    echo "=== Checking llama-cli deps ===" && \
    ldd /usr/local/bin/llama-cli && \
    ! ldd /usr/local/bin/llama-cli | grep "not found" && \
    echo "=== All dependencies satisfied ==="

# Create non-root user
RUN groupadd -g 1001 llama && \
    useradd -u 1001 -g llama -m llama

USER llama

EXPOSE 8080

ENTRYPOINT ["llama-server"]
