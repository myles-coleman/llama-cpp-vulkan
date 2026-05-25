# llama-cpp-vulkan

Multi-arch container image for [llama.cpp](https://github.com/ggerganov/llama.cpp) with Vulkan GPU acceleration

## Image

```
beebecomebigbee/llama-cpp-vulkan:<version>
```

- **Platforms:** `linux/arm64`, `linux/amd64`
- **GPU Backend:** Vulkan (Mesa RADV)
- **Shared Libraries:** Built with `BUILD_SHARED_LIBS=ON`, collected via `find` and verified with `ldd` at build time
- **Entrypoint:** `llama-server`
- **Port:** 8080
- **User:** `llama` (UID 1001, non-root)

## Build Details

The multi-stage Dockerfile:

1. **Builder stage** — Clones llama.cpp HEAD, builds with Vulkan + curl support. On ARM64, targets `cortex-a76`; on AMD64, uses default flags (`GGML_NATIVE=OFF`)
2. **Runtime stage** — Minimal Ubuntu 24.04 with Mesa Vulkan drivers, copies binaries and shared libs, runs `ldd` to verify all dependencies are satisfied before the image is pushed

### Key CMake Flags

| Flag | Value | Purpose |
|------|-------|---------|
| `GGML_VULKAN` | `ON` | Vulkan GPU backend |
| `LLAMA_CURL` | `ON` | HTTP model download support |
| `BUILD_SHARED_LIBS` | `ON` | Build shared libraries |
| `GGML_NATIVE` | `OFF` | Disable host CPU auto-detection |
| `CMAKE_C_FLAGS` | `-mcpu=cortex-a76` (arm64 only) | Target RPi5 CPU (no SVE2) |
| `CMAKE_CXX_FLAGS` | `-mcpu=cortex-a76` (arm64 only) | Target RPi5 CPU (no SVE2) |

## Automated Builds

Pushes to `main` trigger two GitHub Actions workflows:

1. **Release** — Runs [semantic-release](https://github.com/semantic-release/semantic-release) to determine the next version from conventional commits
2. **Build** — Builds and pushes the Docker image to Docker Hub, tagged with the semantic version and `latest`

The build workflow uses a matrix strategy with native runners for each architecture (`ubuntu-24.04-arm` for ARM64, `ubuntu-24.04` for AMD64), then merges them into a single multi-arch manifest.

## Local Build

```bash
# ARM64
docker buildx build --platform linux/arm64 -t llama-cpp-vulkan .

# AMD64
docker buildx build --platform linux/amd64 -t llama-cpp-vulkan .
```

## Usage

```bash
# Download a model
curl -L -o model.gguf https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf

# Run with Vulkan GPU and model
docker run --rm \
  --device /dev/dri/renderD128 \
  --device /dev/dri/card0 \
  -v $(pwd)/model.gguf:/models/model.gguf \
  -p 8080:8080 \
  beebecomebigbee/llama-cpp-vulkan:latest \
  --host 0.0.0.0 --port 8080 -m /models/model.gguf -ngl 99
```

## API

The server exposes an OpenAI-compatible API:

```bash
# Health check
curl http://localhost:8080/health

# List models
curl http://localhost:8080/v1/models

# Chat completion
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello!"}],"max_tokens":128}'
```
