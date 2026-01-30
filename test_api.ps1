# Test script for Piper TTS API

Write-Host "Testing Piper TTS API on http://localhost:5300" -ForegroundColor Cyan

# Test health endpoint
Write-Host "`n1. Testing /health endpoint..." -ForegroundColor Yellow
$health = Invoke-WebRequest -Uri http://localhost:5300/health -Method GET -UseBasicParsing
Write-Host "   Status: $($health.StatusCode)" -ForegroundColor Green
Write-Host "   Response: $($health.Content)" -ForegroundColor Green

# Test synthesis endpoint
Write-Host "`n2. Testing /synthesize endpoint..." -ForegroundColor Yellow
$json = '{"text":"Hola mundo, esta es una prueba de síntesis de voz con Piper TTS."}'
$outputFile = "test_synthesis.wav"

try {
    Invoke-WebRequest -Uri http://localhost:5300/synthesize `
        -Method POST `
        -ContentType "application/json; charset=utf-8" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) `
        -OutFile $outputFile `
        -UseBasicParsing
    
    $fileInfo = Get-Item $outputFile
    Write-Host "   ✓ Synthesis successful!" -ForegroundColor Green
    Write-Host "   File: $($fileInfo.Name)" -ForegroundColor Green
    Write-Host "   Size: $($fileInfo.Length) bytes" -ForegroundColor Green
    Write-Host "`n   You can play the audio file: $outputFile" -ForegroundColor Cyan
}
catch {
    Write-Host "   ✗ Synthesis failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nAPI is ready for n8n integration!" -ForegroundColor Cyan
