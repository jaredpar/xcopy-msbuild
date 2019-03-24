[CmdletBinding(PositionalBinding=$false)]
param (
    [string]$buildToolsDir = "",
    [string]$packageName = "RoslynTools.MSBuild",
    [string]$packageVersion = "16.0.0-rc1-alpha",
    [parameter(ValueFromRemainingArguments=$true)] $extraArgs)

Set-StrictMode -version 2.0
$ErrorActionPreference="Stop"

function Print-Usage() {
    Write-Host "build-msbuild.ps1"
    Write-Host "`t-buildToolsDir path       Path to Build Tools Installation"
    Write-Host "`t-packageName              Name of the nuget package (RoslynTools.MSBuild)"
    Write-Host "`t-packageVersion           Version of the nuget package"
}

function Get-Description() {
    $fileInfo = New-Object IO.FileInfo $msbuildExe
    $sha = & git show-ref HEAD -s
    Write-Host "Creating README.md"
    $text =
"
This is an xcopy version of MSBuild with the following version:

- Product Version: $($fileInfo.VersionInfo.ProductVersion)
- File Version: $($fileInfo.VersionInfo.FileVersion)

This is built using the following tool:

- Repo: https://github.com/jaredpar/xcopy-msbuild
- Source: https://github.com/jaredpar/xcopy-msbuild/commit/$($sha)
"
    return $text
}

function Create-ReadMe() {
    $text = Get-Description
    $text | Out-File (Join-Path $outDir "README.md")
}

function Create-Packages() {
    
    $text = Get-Description
    $nuget = Ensure-NuGet
    Write-Host "Packing $packageName"
    & $nuget pack msbuild.nuspec -ExcludeEmptyDirectories -OutputDirectory $binariesDir -Properties name=$packageName`;version=$packageVersion`;filePath=$outDir`;description=$text
}

Push-Location $PSScriptRoot
try {
    . .\build-utils.ps1

    $msbuildDir = Join-Path $buildToolsDir "MSBuild\Current\Bin"
    $msbuildExe = Join-Path $msbuildDir "msbuild.exe"

    if (-not (Test-Path $buildToolsDir)) { 
        Write-Host "Need a valid value for -buildToolsDir"
        exit 1
    }

    if (-not (Test-Path $msbuildExe)) { 
        Write-Host "Did not find msbuild at $msbuildExe"
        exit 1
    }

    if ($extraArgs -ne $null) {
        Write-Host "Did not recognize extra arguments: $extraArgs"
        Print-Usage
        exit 1
    }
    

    $outDir = Join-Path $binariesDir "BuildTools"
    Create-Directory $outDir -ErrorAction SilentlyContinue | Out-Null
    Remove-Item -re -fo "$outDir\*"
    Write-Host "Copying Build Tools"
    Copy-Item -re "$buildToolsDir\*" $outDir
    Create-ReadMe
    Create-Packages

    exit 0
}
catch [exception] {
    Write-Host $_
    Write-Host $_.Exception
    Write-Host $_.ScriptStackTrace
    exit 1
}
finally {
    Pop-Location
}
