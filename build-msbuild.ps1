[CmdletBinding(PositionalBinding=$false)]
param (
    [string]$msbuildDir = "",
    [string]$msbuildVersion = "15.0",
    [string]$packageName = "RoslynTools.MSBuild",
    [string]$packageVersion = "0.4.0-alpha",
    [parameter(ValueFromRemainingArguments=$true)] $extraArgs)

Set-StrictMode -version 2.0
$ErrorActionPreference="Stop"

function Print-Usage() {
    Write-Host "build-msbuild.ps1"
    Write-Host "`t-msbuildDir path          Path to MSBuild"
    Write-Host "`t-msbuildVersion version   Version of msbuild (default 15.0)"
    Write-Host "\t-packageName              Name of the nuget package (RoslynTools.MSBuild)"
    Write-Host "\t-packageVersion           Version of the nuget package"
}

function Get-PackageMap() {
    $map = @{}
    $x = [xml](Get-Content (Join-Path $repoDir "packages.config"))
    foreach ($p in $x.packages.package) {
        $map[$p.id] = $p.version
    }
    return $map
}

function Compose-Core() { 
    Write-Host "Composing Core Binaries"
    Get-ChildItem $msbuildBinDir | ?{ -not $_.PSIsContainer } | %{ Copy-Item (Join-Path $msbuildBinDir $_) $msbuildOutDir }
    Copy-Item -re (Join-Path $msbuildBinDir "1033") $msbuildOutDir
    Copy-Item -re (Join-Path $msbuildBinDir "en-us") $msbuildOutDir
    Copy-Item -re (Join-Path $msbuildBinDir "Roslyn") $msbuildOutDir
    Copy-Item -re (Join-Path $msbuildBinDir "SdkResolvers") $msbuildOutDir
    Copy-Item (Join-Path $msbuildVersionDir "Microsoft.Common.props") (Join-Path $msbuildOutDir $msbuildVersion)
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
    $text | Out-File (Join-Path $msbuildOutDir "README.md")
}

# The project.json components aren't presently available as a Nuget package.  Compose them 
# together here from an existing MSBuild installation.
function Compose-Projectjson() { 
    Write-Host "Composing project.json support"
    $sourceDir = Join-Path $msbuildDir "Microsoft\NuGet"
    $destDir = Join-Path $msbuildOutDir "Microsoft\NuGet"
    Create-Directory $destDir | Out-Null
    Copy-Item -re "$sourceDir\*" $destDir
    Copy-Item (Join-Path $msbuildVersionDir "Imports\Microsoft.Common.Props\ImportBefore\Microsoft.NuGet.ImportBefore.props") $importPropsBeforeDir
    Copy-Item (Join-Path $msbuildVersionDir "Microsoft.Common.Targets\ImportAfter\Microsoft.NuGet.ImportAfter.targets") $importTargetsAfterDir
}

function Compose-Portable() {
    Write-Host "Composing portable targets"
    $portableDir = Join-Path $msbuildOutDir "Microsoft\Portable"
    Create-Directory $portableDir | Out-Null
    $sourceDir = Join-Path $msbuildDir "Microsoft\Portable"

    Copy-Item (Join-Path $sourceDir "Microsoft.Portable.*") $portableDir
    Copy-Item -re (Join-Path $sourceDir "v5.0") $portableDir
    Copy-Item -re (Join-Path $sourceDir "v4.5") $portableDir
    Copy-Item -re (Join-Path $sourceDir "v4.6") $portableDir
}

function Compose-Sdks() { 
    Write-Host "Composing SDKs"
    $destDir = Join-Path $msbuildOutDir "Sdks"
    $sourceDir = Join-Path $msbuildDir "Sdks"

    Create-Directory $destDir
    Copy-Item -re (Join-Path $sourceDir "Microsoft.Net.Sdk") $destDir
}

function Create-Packages() {
    
    $text = Get-Description
    $nuget = Ensure-NuGet
    Write-Host "Packing $packageName"
    & $nuget pack msbuild.nuspec -ExcludeEmptyDirectories -OutputDirectory $binariesDir -Properties name=$packageName`;version=$packageVersion`;filePath=$msbuildOutDir`;description=$text
}

function Ensure-OutDir([string]$msbuildOutDir) {
    Create-Directory $msbuildOutDir -ErrorAction SilentlyContinue | Out-Null
    Remove-Item -re -fo "$msbuildOutDir\*"
    Create-Directory $importPropsBeforeDir | Out-Null
    Create-Directory $importTargetsBeforeDir | Out-Null
    Create-Directory $importTargetsAfterDir | Out-Null
}

function Test-MSBuildDir() {
    $all = @($msbuildDir, $msbuildBinDir, $msbuildVersionDir, $msbuildExe)
    foreach ($file in $all) { 
        if (-not (Test-Path $file)) { 
            Write-Host "Path doesn't exist $file"
            return $false
        }
    }

    return $true
}

Push-Location $PSScriptRoot
try {
    . .\build-utils.ps1

    $msbuildBinDir = Join-Path $msbuildDir "$msbuildVersion\Bin"
    $msbuildVersionDir = Join-Path $msbuildDir $msbuildVersion
    $msbuildExe = Join-Path $msbuildBinDir "MSBuild.exe"

    if ($extraArgs -ne $null) {
        Write-Host "Did not recognize extra arguments: $extraArgs"
        Print-Usage
        exit 1
    }

    if (-not (Test-MSBuildDir)) { 
        Print-Usage
        exit 1
    }

    $msbuildOutDir = Join-Path $binariesDir "msbuild"
    $importPropsBeforeDir = Join-Path (Join-Path $msbuildOutDir $msbuildVersion) "Imports\Microsoft.Common.props\ImportBefore"
    $importTargetsBeforeDir = Join-Path (Join-Path $msbuildOutDir $msbuildVersion) "Microsoft.Common.targets\ImportBefore"
    $importTargetsAfterDir = Join-Path (Join-Path $msbuildOutDir $msbuildVersion) "Microsoft.Common.targets\ImportAfter"

    Ensure-OutDir $msbuildOutDir
    Compose-Core
    Compose-Projectjson
    Compose-Portable
    Compose-Sdks
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
