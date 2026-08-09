# Whisper (STT)

Fully self-contained Docker image — binaries and models baked in.

## Structure

```
whisper/
├── Dockerfile          # Downloads binaries + models at build time
├── install/            # (optional) local copy for reference
├── models/             # (optional) local copy for reference
└── README.md
```

## Setup

Everything is built into the Docker image. Set your `.env`:

```bash
WHISPER_MODEL=small
WHISPER_PORT=9001
```

Build and run:

```bash
docker compose up --build whisper
```

To switch models, change `WHISPER_MODEL` in `.env` and rebuild:

```bash
docker compose up --build whisper
```

## API

- **Endpoint**: `POST http://localhost:9001/v1/audio/transcriptions`
- **Compatible with**: OpenAI Whisper API format

## Notes

- Uses `whisper-bin-ubuntu-x64` release v1.9.2 (auto-selects CPU backend)
- Multilingual models support 99 languages
- Default model: `small` (~466MB, good balance)
- Alternative: `medium` (~1.5GB, more accurate)
