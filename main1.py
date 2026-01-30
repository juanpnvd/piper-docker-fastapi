import io
import numpy as np
import scipy.io.wavfile
from piper.voice import PiperVoice, SynthesisConfig
import nltk
from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel, Field
from contextlib import asynccontextmanager
import asyncio

# --- CONFIGURATION ---
VOICE_MODEL = "/app/models/es_AR-elena-medium.onnx"
PAUSE_DURATION = 0.6  # Base duration for a full stop
MAX_TEXT_LENGTH = 5000
SYNTHESIS_TIMEOUT = 30  # seconds

# Global voice model
voice = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Load voice model
    global voice
    print(f"Loading voice model: {VOICE_MODEL}")
    voice = PiperVoice.load(VOICE_MODEL)
    print("Voice model loaded successfully")
    yield
    # Shutdown: cleanup if needed
    print("Shutting down...")

app = FastAPI(
    title="Piper TTS API",
    description="""
## High-Quality Spanish Text-to-Speech API

Convert Spanish text to natural-sounding speech using Piper TTS with Elena (Argentina) voice model.

### Features
* 🎯 Fast and efficient synthesis
* 🇦🇷 Native Spanish (Argentina) voice
* 📝 Automatic sentence segmentation
* ⏸️ Smart punctuation-based pauses
* 🎵 Audio fade in/out for smooth transitions
* ⏱️ 30-second timeout protection

### Voice Characteristics
* **Model:** Elena (Argentina Spanish)
* **Quality:** Medium fidelity
* **Speed:** 1.3x (adjustable)
* **Sample Rate:** 22050 Hz
* **Format:** 16-bit WAV

### Limits
* Maximum text length: 5,000 characters
* Synthesis timeout: 30 seconds
* Concurrent requests: Supported
    """,
    version="1.0.0",
    lifespan=lifespan,
    contact={
        "name": "API Support",
        "url": "https://github.com/rhasspy/piper",
    },
    license_info={
        "name": "MIT License",
        "url": "https://opensource.org/licenses/MIT",
    },
)

class TextRequest(BaseModel):
    text: str = Field(
        ..., 
        min_length=1, 
        max_length=MAX_TEXT_LENGTH,
        description="Text to synthesize into speech",
        examples=["Hola mundo, esta es una prueba de síntesis de voz."]
    )

class HealthResponse(BaseModel):
    status: str = Field(description="Service health status", examples=["ok"])

class ErrorResponse(BaseModel):
    detail: str = Field(description="Error message describing what went wrong")

def apply_fades(audio, sr, duration=0.05):
    """Apply fade in/out to audio to prevent clicks"""
    fade_samples = int(sr * duration)
    if len(audio) < fade_samples * 2: return audio
    fade_in = np.linspace(0.0, 1.0, fade_samples)
    fade_out = np.linspace(1.0, 0.0, fade_samples)
    audio[:fade_samples] *= fade_in
    audio[-fade_samples:] *= fade_out
    return audio

def get_punctuation_pause(text, sr, base_duration):
    """Calculate pause duration based on punctuation"""
    if not text: return 0
    last_char = text.strip()[-1]
    if last_char in {'.', '!', '?'}: return int(sr * base_duration)       
    elif last_char in {',', ';', ':'}: return int(sr * (base_duration / 2)) 
    return int(sr * 0.6)

async def synthesize_text(text: str) -> bytes:
    """Synthesize text to WAV audio bytes"""
    if not voice:
        raise RuntimeError("Voice model not loaded")
    
    # Split into sentences using NLTK
    sentences = nltk.sent_tokenize(text, language='spanish')
    
    syn_config = SynthesisConfig(
        volume=1.0,
        length_scale=1.3,
        noise_scale=0.3,
        noise_w_scale=0.3,
        normalize_audio=False,
    )
    
    all_audio_segments = []
    
    for sent in sentences:
        # Get raw audio bytes from Piper
        audio_full = b""
        for chunk in voice.synthesize(sent, syn_config):
            audio_full += chunk.audio_int16_bytes
        
        # Convert to numpy array
        audio_np = np.frombuffer(audio_full, dtype=np.int16).astype(np.float32) / 32768.0
        
        # Apply Fades
        audio_faded = apply_fades(audio_np, voice.config.sample_rate)
        
        # Calculate Pause
        pause_samples = get_punctuation_pause(sent, voice.config.sample_rate, PAUSE_DURATION)
        silence = np.zeros(pause_samples, dtype=np.float32)
        
        # Combine
        segment = np.concatenate([audio_faded, silence])
        all_audio_segments.append(segment)
    
    if not all_audio_segments:
        raise ValueError("No audio generated")
    
    # Concatenate all segments
    final_audio = np.concatenate(all_audio_segments)
    final_audio_int16 = (final_audio * 32767).astype(np.int16)
    
    # Convert to WAV bytes
    wav_buffer = io.BytesIO()
    scipy.io.wavfile.write(wav_buffer, voice.config.sample_rate, final_audio_int16)
    wav_buffer.seek(0)
    
    return wav_buffer.read()

@app.get(
    "/health", 
    response_model=HealthResponse,
    tags=["Health"],
    summary="Health Check",
    description="Check if the TTS service is running and ready to process requests."
)
async def health_check():
    """
    Returns the current health status of the service.
    
    Use this endpoint for:
    - Monitoring and alerting
    - Load balancer health checks
    - Service availability verification
    """
    return {"status": "ok"}

@app.post(
    "/synthesize",
    tags=["Synthesis"],
    summary="Synthesize Text to Speech",
    description="Convert Spanish text to natural speech and receive a WAV audio file.",
    responses={
        200: {
            "description": "Successfully synthesized audio",
            "content": {
                "audio/wav": {
                    "schema": {
                        "type": "string",
                        "format": "binary"
                    }
                }
            }
        },
        400: {
            "description": "Bad Request - Invalid or empty text",
            "model": ErrorResponse
        },
        504: {
            "description": "Gateway Timeout - Synthesis took longer than 30 seconds",
            "model": ErrorResponse
        },
        500: {
            "description": "Internal Server Error - Synthesis failed",
            "model": ErrorResponse
        }
    }
)
async def synthesize(request: TextRequest):
    """
    Convert Spanish text to natural-sounding speech using Piper TTS.
    
    **How it works:**
    1. Text is split into sentences using NLTK
    2. Each sentence is synthesized individually
    3. Automatic pauses are added based on punctuation:
       - Full stops (.), exclamations (!), questions (?) → 0.6s pause
       - Commas (,), semicolons (;), colons (:) → 0.3s pause
    4. Audio fade in/out applied to prevent clicks
    5. All segments are concatenated into a single WAV file
    
    **Parameters:**
    - **text**: Spanish text to synthesize (1-5000 characters)
    
    **Returns:**
    - Binary WAV audio file (16-bit, 22050 Hz)
    - Content-Type: audio/wav
    - Filename: speech.wav
    
    **Example Request:**
    ```json
    {
      "text": "Hola mundo. ¿Cómo estás? Esta es una prueba de síntesis de voz."
    }
    ```
    
    **Processing Time:**
    - Typical: 2-5 seconds per sentence
    - Timeout: 30 seconds maximum
    """
    try:
        # Run synthesis with timeout
        wav_bytes = await asyncio.wait_for(
            synthesize_text(request.text),
            timeout=SYNTHESIS_TIMEOUT
        )
        
        return Response(
            content=wav_bytes,
            media_type="audio/wav",
            headers={
                "Content-Disposition": "attachment; filename=speech.wav"
            }
        )
    
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=504,
            detail=f"Synthesis timeout after {SYNTHESIS_TIMEOUT} seconds"
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Synthesis failed: {str(e)}"
        )