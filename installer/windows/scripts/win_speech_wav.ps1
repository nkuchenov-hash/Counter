# Transcribe a 16-bit PCM WAV file via Windows System.Speech (en-US).
# Usage: powershell -ExecutionPolicy Bypass -File win_speech_wav.ps1 <wavPath>
param(
    [Parameter(Mandatory = $true)][string]$WavPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $WavPath)) {
    Write-Error "WAV not found: $WavPath"
    exit 2
}

try {
    Add-Type -AssemblyName System.Speech
    $culture = [System.Globalization.CultureInfo]::new('en-US')
    $engine = New-Object System.Speech.Recognition.SpeechRecognitionEngine($culture)
    $grammar = New-Object System.Speech.Recognition.DictationGrammar
    $engine.LoadGrammar($grammar)
    $engine.SetInputToWaveFile($WavPath)
    $result = $engine.Recognize()
    if ($null -eq $result) {
        Write-Output ''
        exit 0
    }
    Write-Output $result.Text
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
