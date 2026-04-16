# llama-cpp-vulkan

ARM64 container image for [llama.cpp](https://github.com/ggerganov/llama.cpp) with Vulkan GPU acceleration. Built for use on Raspberry Pi 5 with AMD eGPU (RX 6700 XT) in the [homelab-cluster](https://github.com/myles-coleman/homelab-cluster).

## Image

```
beebecomebigbee/llama-cpp-vulkan:latest
```

- **Platform:** `linux/arm64`
- **GPU Backend:** Vulkan (Mesa RADV)
- **Entrypoint:** `llama-server`
- **Port:** 8080
- **User:** `llama` (UID 1000, non-root)

## Automated Builds

Pushes to `main` trigger a GitHub Actions workflow that builds and pushes the image to Docker Hub. The workflow uses a GitHub Actions ARM runner for native ARM64 builds.

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
# List models
curl http://localhost:8080/v1/models

# Chat completion
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"model","messages":[{"role":"user","content":"Hello!"}]}'
```
