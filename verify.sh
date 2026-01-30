#!/bin/bash
# Script de verificación post-deploy para ARM64
# Ejecutar dentro del container: docker exec <container_id> bash /app/verify.sh

set -e

echo "=== Verificación de Instalación Piper TTS en ARM64 ==="
echo ""

echo "1. Verificando Python..."
python --version

echo ""
echo "2. Verificando que espeakbridge está instalado..."
python -c "from piper import espeakbridge; print('✓ espeakbridge importado correctamente')" || {
    echo "✗ ERROR: No se puede importar espeakbridge"
    exit 1
}

echo ""
echo "3. Verificando PiperVoice..."
python -c "from piper.voice import PiperVoice; print('✓ PiperVoice importado correctamente')" || {
    echo "✗ ERROR: No se puede importar PiperVoice"
    exit 1
}

echo ""
echo "4. Verificando que el modelo existe..."
if [ -f "/app/models/es_AR-elena-medium.onnx" ]; then
    echo "✓ Modelo encontrado: /app/models/es_AR-elena-medium.onnx"
else
    echo "✗ ERROR: Modelo no encontrado"
    exit 1
fi

echo ""
echo "5. Verificando que el modelo se puede cargar..."
python -c "
from piper.voice import PiperVoice
import sys
try:
    voice = PiperVoice.load('/app/models/es_AR-elena-medium.onnx')
    print('✓ Modelo cargado correctamente')
except Exception as e:
    print(f'✗ ERROR: No se puede cargar el modelo: {e}', file=sys.stderr)
    sys.exit(1)
"

echo ""
echo "6. Verificando dependencias críticas..."
python -c "
import onnxruntime
import numpy
import scipy
import nltk
print('✓ onnxruntime:', onnxruntime.__version__)
print('✓ numpy:', numpy.__version__)
print('✓ scipy:', scipy.__version__)
print('✓ nltk:', nltk.__version__)
"

echo ""
echo "7. Verificando espeak-ng..."
if command -v espeak-ng &> /dev/null; then
    echo "✓ espeak-ng instalado"
    espeak-ng --version | head -1
else
    echo "✗ WARNING: espeak-ng no encontrado en PATH"
fi

echo ""
echo "8. Test de síntesis rápida..."
python -c "
from piper.voice import PiperVoice
import io
import wave

voice = PiperVoice.load('/app/models/es_AR-elena-medium.onnx')
audio_bytes = bytes()
for audio_chunk in voice.synthesize_stream_raw('Hola mundo'):
    audio_bytes += audio_chunk

if len(audio_bytes) > 0:
    print(f'✓ Síntesis exitosa: {len(audio_bytes)} bytes generados')
else:
    print('✗ ERROR: No se generó audio')
    exit(1)
"

echo ""
echo "=== ✓ TODAS LAS VERIFICACIONES PASARON ==="
echo "El sistema está listo para producción en ARM64"
