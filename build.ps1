param (
    [string]$msbuildPath = $(throw "Need a path to a valid MSBuild 15.0 installation"),
    [switch]$test = $false)
set-strictmode -version 2.0
$ErrorActionPreference="Stop"

$repoDir = $PSScriptRoot
$binariesDir = join-path $repoDir "binaries"
$outDir = join-path $binariesDir "msbuild"
$outFrameworkDir = join-path  $outDir "Framework"

# TODO: fix this to have the standard calculated values
$packagesDir = "e:\temp\msbuild"

# TODO: hacky values that work for now
$msbuildVersion = "15.0"

$importPropsBeforeDir = join-path (join-path $outDir $msbuildVersion) "Imports\Microsoft.Common.props\ImportBefore"
$importTargetsBeforeDir = join-path (join-path $outDir $msbuildVersion) "Microsoft.Common.targets\ImportBefore"
$importTargetsAfterDir = join-path (join-path $outDir $msbuildVersion) "Microsoft.Common.targets\ImportAfter"

# Download all of the packages needed to compose the xcopy MSBuild
function download-packages() {
    $nuget = join-path $binariesDir "tools\nuget.exe"

    write-host "Downloadnig nuget.exe"
    & src\download-nuget.ps1 -destPath $nuget -version "3.6.0-beta1"

    write-host "Restoring packages"
    & src\restore.ps1 -nuget $nuget -packagesDir $packagesDir
}

function get-packagemap() {
    $map = @{}
    foreach ($line in gc (join-path $repoDir "src\packages.txt")) {
        $all = $line.split(':');
        $map[$all[0]] = $all[1]
    }
    return $map
}

# Compose all of the MSBuild packages together into a valid MSBuild layout
function compose-packages() { 
    write-host "Composing package components"

    mkdir $outDir -ErrorAction SilentlyContinue | out-null
    rm -re -fo "$outDir\*"
    mkdir $outFrameworkDir | out-null
    mkdir $importPropsBeforeDir | out-null
    mkdir $importTargetsBeforeDir | out-null
    mkdir $importTargetsAfterDir | out-null

    $map = get-packagemap
    foreach ($k in $map.Keys) {
        $d = join-path $packagesDir "$($k).$($map[$k])"
        switch -wildcard ($k) {
            "Microsoft.Build.Runtime" { 
                cp -re -fo (join-path $d "contentFiles\any\net46\*") $outDir
                break
            }
            "Microsoft.Build*" { 
                cp -re (join-path $d "lib\net46\*") $outDir
                break
            }
            "Microsoft.Net.Compilers" {
                $roslynDir = join-path $outDir "Roslyn"
                mkdir $roslynDir -ErrorAction SilentlyContinue | out-null
                cp -re (join-path $d "tools\*") $roslynDir
                break
            }
            "System.Collections.Immutable" {
                cp -re (join-path $d "lib\netstandard1.0\*") $outDir
                break
            }
            "System.Threading.Tasks.Dataflow" {
                cp -re (join-path $d "lib\portable-net45+win8+wpa81\*") $outDir
                break
            }
            default { throw "Did not account for $k" }
        }
    }
}

function run-tests() {
    $msbuild = join-path $outDir "msbuild.exe"
    & src\run-tests.ps1 $msbuild
}

# TODO: remove this step once we have a valid package source
#
# The project.json components aren't presently available as a Nuget package.  Compose them 
# together here from an existing MSBuild installation.
function compose-projectjson() { 
    write-host "Composing project.json support"
    $sourceDir = join-path $msbuildPath "Microsoft\NuGet"
    $destDir = join-path $outDir "Microsoft\NuGet"
    mkdir $destDir | out-null
    cp -re "$sourceDir\*" $destDir
    cp (join-path $msbuildPath "15.0\Imports\Microsoft.Common.Props\ImportBefore\Microsoft.NuGet.ImportBefore.props") $importPropsBeforeDir
    cp (join-path $msbuildPath "15.0\Microsoft.Common.Targets\ImportAfter\Microsoft.NuGet.ImportAfter.targets") $importTargetsAfterDir
}

# TODO: remove this step once we have a valid portable location
function compose-portable() {
    write-host "Composing portable targets"
    $portableDir = join-path $outDir "Microsoft\Portable"
    mkdir $portableDir | out-null
    $sourceDir = join-path $msbuildPath "Microsoft\Portable"

    cp (join-path $sourceDir "Microsoft.Portable.*") $portableDir
    cp -re (join-path $sourceDir "v5.0") $portableDir
    cp -re (join-path $sourceDir "v4.5") $portableDir
    cp -re (join-path $sourceDir "v4.6") $portableDir
}

# TODO: remove this step once we have a valid framework asesmbly project
function compose-framework() {
    write-host "Composing reference assemblies"
    $copyList = @(
        ".NETCore\v5.0",
        ".NETFramework\v4.6",
        ".NETFramework\v4.6.1",
        ".NETFramework\v4.6.2",
        ".NETFramework\v4.X"
    )

    $frameworkDir = [IO.Path]::GetPathRoot($msbuildPath)
    $frameworkDir = join-path $frameworkDir "Program Files (x86)\Reference Assemblies\Microsoft\Framework"

    foreach ($item in $copyList) {
        $dest = join-path $outframeworkDir $item
        $source = join-path $frameworkDir $item
        mkdir $dest | out-null
        cp -re $source $dest
    }
}

try {
    pushd $repoDir
    
    download-packages
    compose-packages
    compose-projectjson
    compose-portable
    compose-framework

    if ($test) {
        run-tests
    }

    exit 0
}
catch [exception] {
    write-host $_.Exception
    exit -1
}
finally {
    popd
}
