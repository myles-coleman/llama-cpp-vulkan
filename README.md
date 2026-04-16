# llama-cpp-vulkan

ARM64 container image for [llama.cpp](https://github.com/ggerganov/llama.cpp) with Vulkan GPU acceleration. Built for Raspberry Pi 5 (Cortex-A76) with AMD eGPU (RX 6700 XT) in the [homelab-cluster](https://github.com/myles-coleman/homelab-cluster).

## Image

```
beebecomebigbee/llama-cpp-vulkan:<version>
```

- **Platform:** `linux/arm64`
- **Target CPU:** Cortex-A76 (Raspberry Pi 5)
- **GPU Backend:** Vulkan (Mesa RADV)
- **Shared Libraries:** Built with `BUILD_SHARED_LIBS=ON`, collected via `find` and verified with `ldd` at build time
- **Entrypoint:** `llama-server`
- **Port:** 8080
- **User:** `llama` (UID 1001, non-root)

## Build Details

The multi-stage Dockerfile:

1. **Builder stage** — Clones llama.cpp HEAD, builds with Vulkan + curl support targeting `cortex-a76` (`GGML_NATIVE=OFF`)
2. **Runtime stage** — Minimal Ubuntu 24.04 with Mesa RADV Vulkan drivers, copies binaries and shared libs, runs `ldd` to verify all dependencies are satisfied before the image is pushed

### Key CMake Flags

| Flag | Value | Purpose |
|------|-------|---------|
| `GGML_VULKAN` | `ON` | Vulkan GPU backend |
| `LLAMA_CURL` | `ON` | HTTP model download support |
| `BUILD_SHARED_LIBS` | `ON` | Build shared libraries |
| `GGML_NATIVE` | `OFF` | Disable host CPU auto-detection |
| `CMAKE_C_FLAGS` | `-mcpu=cortex-a76` | Target RPi5 CPU (no SVE2) |
| `CMAKE_CXX_FLAGS` | `-mcpu=cortex-a76` | Target RPi5 CPU (no SVE2) |

## Automated Builds

Pushes to `main` trigger two GitHub Actions workflows:

1. **Release** — Runs [semantic-release](https://github.com/semantic-release/semantic-release) to determine the next version from conventional commits
2. **Build** — Builds and pushes the Docker image to Docker Hub, tagged with the semantic version and `latest`

The build workflow uses a GitHub Actions ARM runner (`ubuntu-24.04-arm`) for native ARM64 builds.

## Local Build

```bash
docker buildx build --platform linux/arm64 -t llama-cpp-vulkan .
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
