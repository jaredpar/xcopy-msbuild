# This script is used to produce a NuGet package contaiting the core 
# reference assemblies.  

[CmdletBinding(PositionalBinding=$false)]
param (
    [string]$root = "c:\",
    [string]$packageName = "RoslynTools.ReferenceAssemblies",
    [string]$packageVersion = "0.0.1-alpha",
    [parameter(ValueFromRemainingArguments=$true)] $extraArgs)
Set-StrictMode -version 2.0
$ErrorActionPreference="Stop"

function Print-Usage() {
    Write-Host "build-reference-assemblies.ps1"
    Write-Host "`t-root path        Root to look for reference assemblies (c:\)"
    Write-Host "\t-packageName      Name of the nuget package (RoslynTools.ReferenceAssemblies)"
    Write-Host "\t-packageVersion   Version of the nuget package"
}

# TODO: remove this step once we have a valid framework assembly project
function Compose-Framework() {
    Write-Host "Composing reference assemblies"
    $copyList = @(
        ".NETCore\v5.0",
        ".NETFramework\v4.0",
        ".NETFramework\v4.5",
        ".NETFramework\v4.6",
        ".NETFramework\v4.6.1",
        ".NETFramework\v4.6.2",
        ".NETFramework\v4.X",
        ".NETPortable\v4.5"
    )

    Create-Directory $outDir
    Remove-Item -re "$outDir\*" 

    $frameworkDir = Join-Path $root "Program Files (x86)\Reference Assemblies\Microsoft\Framework"
    if (-not (Test-Path $frameworkDir)) {
        throw "Reference assembly directory missing: $frameworkDir"
    }

    foreach ($item in $copyList) {
        $dest = Join-Path $outDir $item
        $source = Join-Path $frameworkDir $item
        Create-Directory $dest | Out-Null
        Copy-Item -re "$source\*" $dest
    }
}

function Create-Package() {
    $nuget = Ensure-NuGet
    Write-Host "Packing $packageName"
    & $nuget pack framework.nuspec -ExcludeEmptyDirectories -OutputDirectory $binariesDir -Properties name=$packageName`;version=$packageVersion`;filePath=$outDir
}

Push-Location $PSScriptRoot
try {
    . .\build-utils.ps1

    $outDir = Join-Path $binariesDir "Framework"

    if ($extraArgs -ne $null) {
        Write-Host "Did not recognize extra arguments: $extraArgs"
        Print-Usage
        exit 1
    }

    Compose-Framework
    Create-Package

    exit 0
}
catch {
    Write-Host $_
    Write-Host $_.Exception
    exit 1
}
finally {
    Pop-Location
}
