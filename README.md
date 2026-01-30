# Piper TTS API

A lightweight FastAPI-based text-to-speech service using Piper for high-quality Spanish voice synthesis. Containerized with Docker for easy deployment and n8n workflow integration.

## Features

- 🎯 **REST API** - Simple POST endpoint for text-to-speech conversion
- 🐳 **Docker Ready** - Fully containerized with Docker Compose
- 🇦🇷 **Spanish Voice** - Pre-configured with Elena (Argentina) voice model
- ⚡ **Fast & Lean** - Optimized Python 3.11-slim image
- 🔄 **n8n Compatible** - Returns raw WAV bytes for automation workflows
- 📊 **Auto Documentation** - Built-in Swagger UI at `/docs`
- ❤️ **Health Check** - Monitoring endpoint for availability checks

## Prerequisites

- Docker Desktop (Windows/Mac) or Docker Engine (Linux)
- Docker Compose

## Project Structure

```
voice/
├── main1.py                 # FastAPI application
├── models/                  # Voice models directory
│   ├── es_AR-elena-medium.onnx
│   └── es_AR-elena-medium.onnx.json
├── requirements.txt         # Python dependencies
├── Dockerfile              # Container build instructions
├── docker-compose.yml      # Service orchestration
├── .dockerignore          # Build context exclusions
├── test_api.ps1           # PowerShell test script
└── README.md              # This file
```

## Quick Start

### 1. Build the Docker Image

```bash
docker-compose build
```

This will:
- Pull Python 3.11-slim base image
- Install dependencies (FastAPI, Piper TTS, etc.)
- Download NLTK data for sentence tokenization
- Embed the ONNX voice model into the image

**Build time:** ~2-3 minutes (first time)

### 2. Start the Service

```bash
docker-compose up -d
```

The API will be available at: `http://localhost:5300`

### 3. Verify It's Running

**Option A: Check health endpoint**
```bash
# PowerShell
Invoke-WebRequest -Uri http://localhost:5300/health -UseBasicParsing

# Linux/Mac
curl http://localhost:5300/health
```

**Option B: View logs**
```bash
docker-compose logs -f
```

**Option C: Run test script (PowerShell)**
```powershell
.\test_api.ps1
```

### 4. Access API Documentation

Open your browser and visit:
- **Swagger UI:** http://localhost:5300/docs
- **ReDoc:** http://localhost:5300/redoc

## API Endpoints

### Health Check

**GET** `/health`

Check if the service is running and ready.

**Response:**
```json
{
  "status": "ok"
}
```

**Example:**
```bash
# PowerShell
Invoke-WebRequest -Uri http://localhost:5300/health -UseBasicParsing

# curl
curl http://localhost:5300/health
```

---

### Synthesize Text to Speech

**POST** `/synthesize`

Convert text to speech and receive WAV audio file.

**Request Body:**
```json
{
  "text": "Hola mundo, esta es una prueba de síntesis de voz."
}
```

**Parameters:**
- `text` (string, required): Text to synthesize (max 5000 characters)

**Response:**
- **Content-Type:** `audio/wav`
- **Body:** Binary WAV audio data
- **Status Codes:**
  - `200` - Success (returns WAV audio)
  - `400` - Invalid request (empty text, too long, etc.)
  - `504` - Timeout (synthesis took longer than 30 seconds)
  - `500` - Server error

**Examples:**

**PowerShell:**
```powershell
$json = '{"text":"Hola mundo, esta es una prueba de síntesis de voz."}'
Invoke-WebRequest -Uri http://localhost:5300/synthesize `
    -Method POST `
    -ContentType "application/json; charset=utf-8" `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) `
    -OutFile "output.wav" `
    -UseBasicParsing
```

**curl (Linux/Mac):**
```bash
curl -X POST http://localhost:5300/synthesize \
  -H "Content-Type: application/json" \
  -d '{"text":"Hola mundo, esta es una prueba de síntesis de voz."}' \
  --output output.wav
```

**Python:**
```python
import requests

response = requests.post(
    "http://localhost:5300/synthesize",
    json={"text": "Hola mundo, esta es una prueba de síntesis de voz."}
)

if response.status_code == 200:
    with open("output.wav", "wb") as f:
        f.write(response.content)
```

**JavaScript/Node.js:**
```javascript
const response = await fetch('http://localhost:5300/synthesize', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    text: 'Hola mundo, esta es una prueba de síntesis de voz.'
  })
});

const audioBuffer = await response.arrayBuffer();
await fs.promises.writeFile('output.wav', Buffer.from(audioBuffer));
```

## n8n Integration

### HTTP Request Node Configuration

1. **Method:** POST
2. **URL:** `http://localhost:5300/synthesize`
3. **Authentication:** None
4. **Body Content Type:** JSON
5. **JSON/RAW Parameters:**
   ```json
   {
     "text": "{{ $json.textToSynthesize }}"
   }
   ```
6. **Response Format:** File
7. **Put Output in Field:** `data`

The audio will be available as binary data for further processing or storage.

## Configuration

### Voice Model Settings

Current configuration in [main1.py](main1.py):
- **Voice:** Elena (Argentina Spanish)
- **Speed:** 1.3x (length_scale)
- **Quality:** Medium fidelity
- **Max text length:** 5000 characters
- **Synthesis timeout:** 30 seconds

### Synthesis Parameters

Fixed optimal values:
- **volume:** 1.0
- **length_scale:** 1.3 (speech speed)
- **noise_scale:** 0.3 (variability)
- **noise_w_scale:** 0.3 (phoneme duration variability)
- **Pause duration:** 0.6s for full stops, 0.3s for commas

### Port Configuration

Default port: `5300`

To change the port, edit [docker-compose.yml](docker-compose.yml):
```yaml
ports:
  - "YOUR_PORT:5300"
```

## Docker Commands

### View Logs
```bash
docker-compose logs -f
```

### Stop the Service
```bash
docker-compose down
```

### Restart the Service
```bash
docker-compose restart
```

### Rebuild After Changes
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Check Container Status
```bash
docker-compose ps
```

### Access Container Shell
```bash
docker exec -it piper-tts-api /bin/bash
```

## Troubleshooting

### Container won't start
```bash
# Check logs for errors
docker-compose logs

# Verify port is not in use
# Windows PowerShell:
Get-NetTCPConnection -LocalPort 5300

# Linux/Mac:
lsof -i :5300
```

### Synthesis fails or timeouts
- Check text length (max 5000 chars)
- Verify model files exist in container: `docker exec piper-tts-api ls -la /app/models/`
- Increase timeout in [main1.py](main1.py) if needed

### Audio quality issues
Adjust synthesis parameters in [main1.py](main1.py):
- Decrease `length_scale` for faster speech
- Adjust `noise_scale` for more/less variability

## Performance

- **Startup time:** ~2-3 seconds
- **Synthesis speed:** ~2-5 seconds per sentence
- **Memory usage:** ~500MB
- **Image size:** ~1.5GB (includes model)

## Development

### Local Testing Without Docker
```bash
# Install dependencies
pip install -r requirements.txt

# Download NLTK data
python -m nltk.downloader punkt punkt_tab

# Set voice model path in main1.py to local path
# Then run:
uvicorn main1:app --reload --port 5300
```

### Adding New Voice Models

1. Download ONNX model from [Piper Voices](https://github.com/rhasspy/piper/blob/master/VOICES.md)
2. Copy `.onnx` and `.onnx.json` files to `models/` directory
3. Update `VOICE_MODEL` path in [main1.py](main1.py)
4. Rebuild Docker image

## License

This project uses:
- **FastAPI** - MIT License
- **Piper TTS** - MIT License
- **NLTK** - Apache License 2.0

## Support

For issues or questions:
1. Check the Swagger docs at http://localhost:5300/docs
2. Review container logs: `docker-compose logs`
3. Verify all model files are present in `models/` directory

---

**Built with ❤️ using FastAPI and Piper TTS**
