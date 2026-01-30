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
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:$LD_LIBRARY_PATH

# Install build dependencies first
RUN pip install --no-cache-dir setuptools wheel scikit-build

# Install other Python dependencies
RUN pip install --no-cache-dir fastapi uvicorn scipy nltk numpy onnxruntime pydub

# Clone and compile piper-tts from source (includes CMakeLists.txt)
# This is necessary because PyPI tarball doesn't include build files
RUN echo "=== Cloning piper-tts from GitHub ===" && \
    git clone --depth 1 https://github.com/OHF-Voice/piper1-gpl.git /tmp/piper && \
    cd /tmp/piper && \
    echo "=== Compiling piper-tts with espeakbridge (8-12 min on ARM64) ===" && \
    pip install --no-cache-dir --verbose . && \
    echo "=== Verifying espeakbridge compiled correctly ===" && \
    python -c "from piper import espeakbridge; print('✓ espeakbridge loaded')" && \
    python -c "from piper.voice import PiperVoice; print('✓ PiperVoice loaded')" && \
    cd / && rm -rf /tmp/piper && \
    echo "=== SUCCESS: piper-tts compiled and verified ==="

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
