# PowerShell wrapper script - delegates to the Python script which handles everything
param(
    [string]$AppConfigName,
    [switch]$DryRun,
    [switch]$Verbose
)

Write-Host "🤖 Starting AI model and agent deployment..."
Write-Host "🔄 Delegating to Python script for better Azure SDK integration..."

try {
    # Try to find Python - check virtual environment first, then system Python
    $pythonExe = $null
    
    # Check if we're in the project directory and have a virtual environment
    if (Test-Path ".venv\Scripts\python.exe") {
        $pythonExe = ".venv\Scripts\python.exe"
        Write-Host "✅ Using Python from virtual environment"
    } elseif (Test-Path "venv\Scripts\python.exe") {
        $pythonExe = "venv\Scripts\python.exe"
        Write-Host "✅ Using Python from virtual environment"
    } else {
        # Fall back to system Python
        $systemPython = Get-Command python -ErrorAction SilentlyContinue
        if ($systemPython) {
            $pythonExe = "python"
            Write-Host "✅ Using system Python"
        }
    }
    
    if (-not $pythonExe) {
        Write-Host "❌ Python not found. Please install Python or create a virtual environment."
        Write-Host "💡 You can create a virtual environment with: python -m venv .venv"
        exit 1
    }

    # Install required packages if using virtual environment
    if ($pythonExe -like "*venv*") {
        Write-Host "📦 Ensuring required Python packages are installed..."
        & $pythonExe -m pip install -r "scripts\requirements-swap-agent.txt" --quiet --disable-pip-version-check
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️ Warning: Failed to install Python packages. Continuing anyway..."
        }
    }

    # Build arguments for Python script
    $pythonArgs = @("scripts\postdeploy-update-agent.py")
    
    if ($AppConfigName) {
        $pythonArgs += "--app-config"
        $pythonArgs += $AppConfigName
    }
    
    if ($DryRun) {
        $pythonArgs += "--dry-run"
    }
    
    if ($Verbose) {
        $pythonArgs += "--verbose"
    }

    # Run the Python script with arguments
    Write-Host "▶️ Running: $pythonExe $($pythonArgs -join ' ')"
    & $pythonExe @pythonArgs
    exit $LASTEXITCODE

} catch {
    Write-Error "❌ Failed to run Python deployment script: $_"
    exit 1
}