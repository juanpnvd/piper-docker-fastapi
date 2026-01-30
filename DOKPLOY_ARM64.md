# Instrucciones para Deploy en ARM64 (Dokploy)

## Problema Resuelto
El error `ModuleNotFoundError: No module named 'espeakbridge'` ocurre en ARM64 porque `piper-tts` no tiene wheels pre-compilados para esta arquitectura. El módulo `espeakbridge` es una extensión C que debe compilarse durante la instalación.

## Solución Implementada

### 1. Dockerfile Actualizado
Se agregaron las herramientas de build necesarias:
- `build-essential` (gcc, g++, make)
- `cmake` (≥3.26 requerido por piper)
- `ninja-build` (sistema de build)
- `git` (para clonar espeak-ng durante build)

### 2. .dockerignore Actualizado
Se excluyó el directorio `piper1-gpl/` para evitar conflictos con el paquete PyPI.

## Pasos para Deploy en Dokploy

### 1. Forzar Rebuild Completo
En Dokploy, ejecuta:
```bash
docker system prune -a  # Limpiar todas las imágenes cacheadas
```

### 2. Rebuild con No-Cache
Asegúrate que Dokploy use:
```bash
docker build --no-cache --platform linux/arm64 -t piper-tts-api .
```

### 3. Verificar el Build
El proceso de instalación de `piper-tts` tardará **5-10 minutos** en ARM64 porque debe:
- Clonar espeak-ng desde GitHub
- Compilar espeak-ng como biblioteca estática
- Compilar el módulo C `espeakbridge`
- Copiar los datos de espeak-ng-data

Verás output similar a:
```
Collecting piper-tts
  Downloading piper_tts-1.4.0.tar.gz
Building wheels for collected packages: piper-tts
  Building wheel for piper-tts (pyproject.toml): started
  ...
  Building wheel for piper-tts (pyproject.toml): finished with status 'done'
```

### 4. Verificar que el Container Funciona
Una vez deployado, verifica:
```bash
docker exec <container> python -c "from piper.voice import PiperVoice; print('OK')"
```

Debe imprimir `OK` sin errores.

## Tiempo de Build
- **ARM64**: ~8-12 minutos (compila desde source)
- **AMD64/x86_64**: ~2-3 minutos (usa wheel pre-compilado)

## Dependencias Críticas
Las siguientes dependencias son **esenciales** para compilar en ARM64:
```dockerfile
build-essential    # gcc, g++, make
cmake             # Sistema de build de piper
ninja-build       # Backend de cmake
git               # Clonar espeak-ng
libespeak-ng-dev  # Headers de espeak-ng
```

## Notas Importantes
- No elimines `build-essential`, `cmake`, o `ninja-build` del Dockerfile
- El directorio `piper1-gpl/` en tu workspace es solo para referencia, **no se usa** en el build
- Si ves errores de CMake, verifica que cmake ≥3.18 esté instalado (python:3.11-slim incluye 3.25+)

## Troubleshooting

### Error: "Could not find CMAKE_MAKE_PROGRAM"
```bash
# Instalar ninja-build
RUN apt-get install -y ninja-build
```

### Error: "espeak_ng_external clone failed"
```bash
# Instalar git
RUN apt-get install -y git
```

### Build muy lento
Esto es normal en ARM64. El build de espeak-ng tarda varios minutos. Considera usar multi-stage build si necesitas optimizar.
