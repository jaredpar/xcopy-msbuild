param ([switch]$test = $false)
set-strictmode -version 2.0
$ErrorActionPreference="Stop"

$repoDir = $PSScriptRoot
$binariesDir = join-path $repoDir "binaries"
$msbuildDir = join-path  $binariesDir "msbuild"

# TODO: fix this to have the standard calculated values
$packagesDir = "e:\temp\msbuild"

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

function compose-packages() { 
    write-host "Composing packages"
    mkdir $msbuildDir -ErrorAction SilentlyContinue | out-null
    rm -re "$msbuildDir\*"

    $map = get-packagemap
    foreach ($k in $map.Keys) {
        $d = join-path $packagesDir "$($k).$($map[$k])"
        switch -wildcard ($k) {
            "Microsoft.Build.Runtime" { 
                cp -re -fo (join-path $d "contentFiles\any\net46\*") $msbuildDir
                break
            }
            "Microsoft.Build*" { 
                cp -re -fo (join-path $d "lib\net46\*") $msbuildDir
                break
            }
            "Microsoft.Net.Compilers" {
                $roslynDir = join-path $msbuildDir "Roslyn"
                mkdir $roslynDir | out-null
                cp -re -fo (join-path $d "tools\*") $roslynDir
                break
            }
            "System.Collections.Immutable" {
                cp -re -fo (join-path $d "lib\netstandard1.0\*") $msbuildDir
                break
            }
            default { throw "Did not account for $k" }
        }
    }
}

function run-tests() {
    $msbuild = join-path $msbuildDir "msbuild.exe"
    & src\run-tests.ps1 $msbuild
}

try {
    pushd $repoDir
    
    download-packages
    compose-packages

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
