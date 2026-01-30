FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install build tools and runtime dependencies for ARM64
# Build tools needed to compile espeakbridge C extension
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    python3-dev \
    espeak-ng \
    libespeak-ng1 \
    libespeak-ng-dev \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:$LD_LIBRARY_PATH

# Copy requirements first for better caching
COPY requirements.txt .

# Install dependencies
# CRITICAL: Force piper-tts compilation from source (don't use potentially broken wheel)
RUN echo "=== Installing other dependencies with wheels ===" && \
    pip install --no-cache-dir fastapi uvicorn scipy nltk numpy && \
    echo "=== Compiling piper-tts from source (this takes 8-12 min on ARM64) ===" && \
    pip install --no-cache-dir --no-binary piper-tts piper-tts && \
    echo "=== Verifying espeakbridge compiled correctly ===" && \
    python -c "from piper import espeakbridge; print('✓ espeakbridge loaded')" && \
    python -c "from piper.voice import PiperVoice; print('✓ PiperVoice loaded')" && \
    echo "=== SUCCESS: piper-tts installed and verified ==="

# Download NLTK data during build
RUN python -m nltk.downloader punkt punkt_tab

# Copy voice models
COPY models/ /app/models/

# Copy application code and verification script
COPY main1.py .
COPY verify.sh .
RUN chmod +x verify.sh

# Expose port
EXPOSE 5300

# Run the application
CMD ["uvicorn", "main1:app", "--host", "0.0.0.0", "--port", "5300"]
