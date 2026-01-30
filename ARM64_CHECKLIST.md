# ✅ Checklist Pre-Deploy ARM64

## Dependencias Verificadas

### ✅ Build Tools (CRÍTICO para ARM64)
- [x] `build-essential` - gcc, g++, make para compilar C/C++
- [x] `cmake` ≥3.26 - Sistema de build (disponible: 3.31)
- [x] `ninja-build` - Backend de build
- [x] `git` - Para clonar espeak-ng durante build
- [x] `python3-dev` - Headers de Python para extensiones C

### ✅ Runtime Dependencies
- [x] `espeak-ng` - Binario de phonemizer
- [x] `libespeak-ng1` - Runtime library
- [x] `libespeak-ng-dev` - Headers para compilar espeakbridge
- [x] `libsndfile1` - Para audio I/O

### ✅ Python Requirements
- [x] `piper-tts` - Se compilará desde source en ARM64
- [x] `fastapi` - Framework API
- [x] `uvicorn` - ASGI server
- [x] `scipy` - Procesamiento científico
- [x] `nltk` - NLP tools
- [x] `numpy` - Arrays numéricos

## Archivos Críticos

### ✅ Dockerfile
```dockerfile
- Usa python:3.11-slim base
- Instala python3-dev (NUEVO - crítico para ARM64)
- Instala build-essential, cmake, ninja-build, git
- Instala espeak-ng y librerías dev
- pip install compila piper-tts desde source
```

### ✅ .dockerignore
```
- Excluye piper1-gpl/ (evita conflictos)
- Excluye test_api.ps1 (script Windows)
- Incluye verify.sh (script de verificación)
```

### ✅ verify.sh
- Script de verificación post-deploy
- Verifica que espeakbridge se importa correctamente
- Verifica que el modelo carga
- Test de síntesis básico

## Proceso de Build Esperado

### Fase 1: Instalación de Dependencias del Sistema (~2 min)
```
apt-get update
apt-get install build-essential cmake ninja-build git python3-dev...
```

### Fase 2: Compilación de piper-tts (~8-12 min en ARM64)
```
pip install piper-tts
  ↓
1. Descarga source de piper-tts desde PyPI
2. scikit-build ejecuta CMake
3. CMake clona espeak-ng desde GitHub
4. Compila espeak-ng estáticamente (~5 min)
5. Compila espeakbridge.so (~1 min)
6. Copia espeak-ng-data
7. Construye wheel de piper-tts
8. Instala wheel
```

### Fase 3: Setup Final (~1 min)
```
- Descarga NLTK punkt data
- Copia modelo ONNX
- Copia código de aplicación
```

**Tiempo total estimado: 11-15 minutos**

## Logs Esperados Durante Build

### ✅ Señales de Éxito
```
Collecting piper-tts
  Downloading piper_tts-1.4.0.tar.gz
Building wheels for collected packages: piper-tts
  Building wheel for piper-tts (pyproject.toml): started
  running build_ext
  -- The C compiler identification is GNU
  -- The CXX compiler identification is GNU
  -- Configuring espeak-ng
  -- Building espeak-ng
  -- Installing espeak-ng
  -- Building espeakbridge
  Building wheel for piper-tts (pyproject.toml): finished with status 'done'
Successfully built piper-tts
Successfully installed piper-tts-1.4.0
```

### ❌ Señales de Error a Vigilar
```
ERROR: Could not build wheels for piper-tts
error: command 'cmake' failed
error: command 'gcc' failed
fatal: unable to clone espeak-ng
ModuleNotFoundError: No module named 'skbuild'
```

## Comandos de Verificación en Dokploy

### 1. Verificar que el build incluye compilación
```bash
# Los logs deben mostrar:
# "Building wheel for piper-tts"
# "Building espeakbridge"
# "espeak_ng_external-build"
```

### 2. Después del deploy, ejecutar verificación
```bash
docker exec <container_id> bash /app/verify.sh
```

### 3. Test manual de importación
```bash
docker exec <container_id> python -c "from piper import espeakbridge; print('OK')"
```

### 4. Test de síntesis
```bash
docker exec <container_id> python -c "
from piper.voice import PiperVoice
voice = PiperVoice.load('/app/models/es_AR-elena-medium.onnx')
print('Modelo cargado OK')
"
```

## Diferencias ARM64 vs AMD64

| Aspecto | AMD64/x86_64 | ARM64/aarch64 |
|---------|--------------|---------------|
| piper-tts | Wheel pre-compilado | Compila desde source |
| Build time | 2-3 min | 11-15 min |
| Build tools | No necesarios* | **CRÍTICOS** |
| python3-dev | No necesario* | **CRÍTICO** |
| Dockerfile | Más simple | Más complejo |

*Técnicamente pip podría fallar sin build tools si falta algún wheel

## Checklist Final Pre-Deploy

- [ ] Dockerfile incluye `python3-dev`
- [ ] Dockerfile incluye `build-essential cmake ninja-build git`
- [ ] .dockerignore excluye `piper1-gpl/`
- [ ] requirements.txt tiene `piper-tts` sin versión pinneada
- [ ] Modelo ONNX está en `models/es_AR-elena-medium.onnx`
- [ ] verify.sh está copiado al container
- [ ] Dokploy configurado para `--no-cache` build
- [ ] Timeout de build en Dokploy ≥20 minutos

## Post-Deploy

- [ ] Ejecutar `verify.sh` en el container
- [ ] Verificar logs de uvicorn: "Voice model loaded successfully"
- [ ] Test de endpoint: `curl http://localhost:5300/synthesize -d '{"text":"Hola"}'`
- [ ] Verificar que el audio se genera correctamente

## Troubleshooting Rápido

| Error | Solución |
|-------|----------|
| `No module named 'espeakbridge'` | Falta python3-dev o build tools |
| `cmake not found` | Falta cmake en apt-get |
| `ninja: not found` | Falta ninja-build en apt-get |
| `Python.h: No such file` | Falta python3-dev |
| Build timeout | Aumentar timeout a 20+ min |
| `git: command not found` | Falta git en apt-get |

---

**TODO LISTO PARA BUILD** ✅

El Dockerfile ahora tiene todas las dependencias necesarias para compilar piper-tts desde source en ARM64.
