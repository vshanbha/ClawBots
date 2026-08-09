FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget unzip libgomp1 ffmpeg \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download whisper binaries (platform/arch configurable)
ARG WHISPER_VERSION
ARG WHISPER_PLATFORM=ubuntu
ARG WHISPER_ARCH=x64
RUN mkdir -p /whisper/install \
    && wget -q "https://github.com/ggml-org/whisper.cpp/releases/download/v${WHISPER_VERSION}/whisper-bin-${WHISPER_PLATFORM}-${WHISPER_ARCH}.tar.gz" -O /tmp/whisper.tar.gz \
    && tar xzf /tmp/whisper.tar.gz -C /whisper/install --strip-components=1 \
    && rm -f /tmp/whisper.tar.gz

# Download models
ARG WHISPER_MODEL=small
RUN mkdir -p /whisper/models \
    && wget -q "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${WHISPER_MODEL}.bin" \
         -O /whisper/models/ggml-${WHISPER_MODEL}.bin

ENV LD_LIBRARY_PATH=/whisper/install
ENV PATH="/whisper/install:${PATH}"

EXPOSE 9001

ENTRYPOINT ["whisper-server"]
