FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Prevent debconf warnings
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies and runtime libraries
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    espeak-ng \
    libespeak-ng1 \
    libespeak-ng-dev \
    libsndfile1 \
    libsndfile1-dev \
    && rm -rf /var/lib/apt/lists/*

# Set library path for espeak-ng
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

# Copy requirements first for better caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Download NLTK data during build
RUN python -m nltk.downloader punkt punkt_tab

# Copy voice models
COPY models/ /app/models/

# Copy application code
COPY main1.py .

# Expose port
EXPOSE 5300

# Run the application
CMD ["uvicorn", "main1:app", "--host", "0.0.0.0", "--port", "5300"]
