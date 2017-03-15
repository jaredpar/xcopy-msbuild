param (
    [string]$msbuildPath = $(throw "Need a path to a valid MSBuild 15.0 installation"),
    [switch]$test = $false)
Set-StrictMode -version 2.0
$ErrorActionPreference="Stop"

$repoDir = $PSScriptRoot
$binariesDir = Join-Path $repoDir "binaries"
$outDir = Join-Path $binariesDir "msbuild"
$outFrameworkDir = Join-Path  $outDir "Framework"
$nuget = Join-Path $binariesDir "tools\nuget.exe"

# TODO: hacky values that work for now
$msbuildVersion = "15.0"

$importPropsBeforeDir = Join-Path (Join-Path $outDir $msbuildVersion) "Imports\Microsoft.Common.props\ImportBefore"
$importTargetsBeforeDir = Join-Path (Join-Path $outDir $msbuildVersion) "Microsoft.Common.targets\ImportBefore"
$importTargetsAfterDir = Join-Path (Join-Path $outDir $msbuildVersion) "Microsoft.Common.targets\ImportAfter"

function Create-Directory([string]$dir) {
    New-Item $dir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
}

function Get-PackagesDir {
    $d = $null
    if ($env:NUGET_PACKAGES -ne $null) {
        $d = $env:NUGET_PACKAGES
    }
    else {
        $d = Join-Path $env:UserProfile ".nuget\packages\"
    }

    Create-Directory $d
    return $d
}

function Download-NuGet() {
    if (-not (Test-Path $nuget)) {
        Create-Directory (Split-Path -parent $nuget)
        $version = "3.6.0-beta1"
        Write-Host "Downloading NuGet.exe $version"
        $webClient = New-Object -TypeName "System.Net.WebClient"
        $webClient.DownloadFile("https://dist.nuget.org/win-x86-commandline/v$version/NuGet.exe", $nuget)
    }
}

# Download all of the packages needed to compose the xcopy MSBuild
function Download-Packages() {
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
    Create-Directory $outFrameworkDir | Out-Null
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

function Run-Tests() {
    $msbuild = Join-Path $outDir "msbuild.exe"
    & src\run-tests.ps1 $msbuild
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
    $readmePath = Join-Path $outDir "README.md"
    $text | Out-File $readmePath
}

# TODO: remove this step once we have a valid package source
#
# The project.json components aren't presently available as a Nuget package.  Compose them 
# together here from an existing MSBuild installation.
function Compose-Projectjson() { 
    Write-Host "Composing project.json support"
    $sourceDir = Join-Path $msbuildPath "Microsoft\NuGet"
    $destDir = Join-Path $outDir "Microsoft\NuGet"
    Create-Directory $destDir | Out-Null
    Copy-Item -re "$sourceDir\*" $destDir
    Copy-Item (Join-Path $msbuildPath "15.0\Imports\Microsoft.Common.Props\ImportBefore\Microsoft.NuGet.ImportBefore.props") $importPropsBeforeDir
    Copy-Item (Join-Path $msbuildPath "15.0\Microsoft.Common.Targets\ImportAfter\Microsoft.NuGet.ImportAfter.targets") $importTargetsAfterDir
}

# TODO: remove this step once we have a valid portable location
function Compose-Portable() {
    Write-Host "Composing portable targets"
    $portableDir = Join-Path $outDir "Microsoft\Portable"
    Create-Directory $portableDir | Out-Null
    $sourceDir = Join-Path $msbuildPath "Microsoft\Portable"

    Copy-Item (Join-Path $sourceDir "Microsoft.Portable.*") $portableDir
    Copy-Item -re (Join-Path $sourceDir "v5.0") $portableDir
    Copy-Item -re (Join-Path $sourceDir "v4.5") $portableDir
    Copy-Item -re (Join-Path $sourceDir "v4.6") $portableDir
}

# TODO: remove this step once we have a valid framework asesmbly project
function Compose-Framework() {
    Write-Host "Composing reference assemblies"
    $copyList = @(
        ".NETCore\v5.0",
        ".NETFramework\v4.0",
        ".NETFramework\v4.6",
        ".NETFramework\v4.6.1",
        ".NETFramework\v4.6.2",
        ".NETFramework\v4.X",
        ".NETPortable\v4.5"
    )

    $frameworkDir = [IO.Path]::GetPathRoot($msbuildPath)
    $frameworkDir = Join-Path $frameworkDir "Program Files (x86)\Reference Assemblies\Microsoft\Framework"

    foreach ($item in $copyList) {
        $dest = Join-Path $outframeworkDir $item
        $source = Join-Path $frameworkDir $item
        Create-Directory $dest | Out-Null
        Copy-Item -re "$source\*" $dest
    }
}

function Zip-MSBuild() { 
    Write-Host "Creating zip file"

    $zipFile = Join-Path $binariesDir "msbuild.zip"
    Remove-Item $zipFile -ErrorAction SilentlyContinue
    Add-Type -Assembly System.IO.Compression.FileSystem
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    [IO.Compression.ZipFile]::CreateFromDirectory($outDir, $zipFile, $compressionLevel, $true)
}

try {
    Push-Location $repoDir
    
    Download-NuGet
    Download-Packages
    Compose-Packages
    Compose-Projectjson
    Compose-Portable
    Compose-Framework
    Create-ReadMe
    Zip-MSBuild

    if ($test) {
        run-tests
    }

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
