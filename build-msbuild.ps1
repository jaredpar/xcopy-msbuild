[CmdletBinding(PositionalBinding=$false)]
param (
    [string]$msbuildDir = "",
    [string]$packageName = "RoslynTools.MSBuild",
    [string]$packageVersion = "0.0.1-alpha",
    [parameter(ValueFromRemainingArguments=$true)] $extraArgs)

Set-StrictMode -version 2.0
$ErrorActionPreference="Stop"

# TODO: hacky values that work for now
$msbuildVersion = "15.0"

function Print-Usage() {
    Write-Host "build-msbuild.ps1"
    Write-Host "`t-msbuildDir path  Path to MSBuild"
    Write-Host "\t-packageName      Name of the nuget package (RoslynTools.MSBuild)"
    Write-Host "\t-packageVersion   Version of the nuget package"
}

# Download all of the packages needed to compose the xcopy MSBuild
function Download-Packages() {
    $nuget = Ensure-NuGet

    Write-Host "Restoring packages"
    $packagesDir = Get-PackagesDir
    $configFilePath = Join-Path $PSScriptRoot "packages.config"
    $output = & $nuget restore $configFilePath -PackagesDirectory $packagesDir | out-null
    if (-not $?) {
        Write-Host $output
        throw "Restore failed"
    }
}

function Get-PackageMap() {
    $map = @{}
    $x = [xml](Get-Content (Join-Path $repoDir "packages.config"))
    foreach ($p in $x.packages.package) {
        $map[$p.id] = $p.version
    }
    return $map
}

# Compose all of the MSBuild packages together into a valid MSBuild layout
function Compose-Packages() { 
    Write-Host "Composing package components"

    Create-Directory $outDir -ErrorAction SilentlyContinue | Out-Null
    Remove-Item -re -fo "$outDir\*"
    Create-Directory $importPropsBeforeDir | Out-Null
    Create-Directory $importTargetsBeforeDir | Out-Null
    Create-Directory $importTargetsAfterDir | Out-Null

    $packagesDir = Get-PackagesDir
    $map = Get-PackageMap
    foreach ($k in $map.Keys) {
        $d = Join-Path $packagesDir "$($k).$($map[$k])"
        switch -wildcard ($k) {
            "Microsoft.Build.Runtime" { 
                Copy-Item -re -fo (Join-Path $d "contentFiles\any\net46\*") $outDir
                break
            }
            "Microsoft.Build*" { 
                Copy-Item -re (Join-Path $d "lib\net46\*") $outDir
                break
            }
            "Microsoft.Net.Compilers" {
                $roslynDir = Join-Path $outDir "Roslyn"
                Create-Directory $roslynDir -ErrorAction SilentlyContinue | Out-Null
                Copy-Item -re (Join-Path $d "tools\*") $roslynDir
                break
            }
            "System.Collections.Immutable" {
                Copy-Item -re (Join-Path $d "lib\netstandard1.0\*") $outDir
                break
            }
            "System.Threading.Tasks.Dataflow" {
                Copy-Item -re (Join-Path $d "lib\portable-net45+win8+wpa81\*") $outDir
                break
            }
            default { throw "Did not account for $k" }
        }
    }
}

function Create-ReadMe() {
    $sha = & git show-ref HEAD -s
    Write-Host "Creating README.md"
    $text =
"
This is an xcopy version of MSBuild generated from:

- Repo: https://github.com/jaredpar/xcopy-msbuild
- SHA: $($sha)
- Source: https://github.com/jaredpar/xcopy-msbuild/commit/$($sha)
"
    $text | Out-File (Join-Path $outDir "README.md")
}

# TODO: remove this step once we have a valid package source
#
# The project.json components aren't presently available as a Nuget package.  Compose them 
# together here from an existing MSBuild installation.
function Compose-Projectjson() { 
    Write-Host "Composing project.json support"
    $sourceDir = Join-Path $msbuildDir "Microsoft\NuGet"
    $destDir = Join-Path $outDir "Microsoft\NuGet"
    Create-Directory $destDir | Out-Null
    Copy-Item -re "$sourceDir\*" $destDir
    Copy-Item (Join-Path $msbuildDir "15.0\Imports\Microsoft.Common.Props\ImportBefore\Microsoft.NuGet.ImportBefore.props") $importPropsBeforeDir
    Copy-Item (Join-Path $msbuildDir "15.0\Microsoft.Common.Targets\ImportAfter\Microsoft.NuGet.ImportAfter.targets") $importTargetsAfterDir
}

# TODO: remove this step once we have a valid portable location
function Compose-Portable() {
    Write-Host "Composing portable targets"
    $portableDir = Join-Path $outDir "Microsoft\Portable"
    Create-Directory $portableDir | Out-Null
    $sourceDir = Join-Path $msbuildDir "Microsoft\Portable"

    Copy-Item (Join-Path $sourceDir "Microsoft.Portable.*") $portableDir
    Copy-Item -re (Join-Path $sourceDir "v5.0") $portableDir
    Copy-Item -re (Join-Path $sourceDir "v4.5") $portableDir
    Copy-Item -re (Join-Path $sourceDir "v4.6") $portableDir
}

function Create-Packages() {
    
    $nuget = Ensure-NuGet
    Write-Host "Packing $packageName"
    & $nuget pack msbuild.nuspec -ExcludeEmptyDirectories -OutputDirectory $binariesDir -Properties name=$packageName`;version=$packageVersion`;filePath=$outDir
}

Push-Location $PSScriptRoot
try {
    . .\build-utils.ps1

    $outDir = Join-Path $binariesDir "msbuild"
    $importPropsBeforeDir = Join-Path (Join-Path $outDir $msbuildVersion) "Imports\Microsoft.Common.props\ImportBefore"
    $importTargetsBeforeDir = Join-Path (Join-Path $outDir $msbuildVersion) "Microsoft.Common.targets\ImportBefore"
    $importTargetsAfterDir = Join-Path (Join-Path $outDir $msbuildVersion) "Microsoft.Common.targets\ImportAfter"


    if ($extraArgs -ne $null) {
        Write-Host "Did not recognize extra arguments: $extraArgs"
        Print-Usage
        exit 1
    }

    if (-not (Test-Path $msbuildDir)) {
        Write-Host "msbuildDir must point to a valid MSBuild installation"
        Print-Usage
        exit 1
    }

    Download-Packages
    Compose-Packages
    Compose-Projectjson
    Compose-Portable
    Create-ReadMe
    Create-Packages

    exit 0
}
catch [exception] {
    Write-Host $_
    Write-Host $_.Exception
    exit 1
}
finally {
    Pop-Location
}
