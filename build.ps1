param ()
set-strictmode -version 2.0
$ErrorActionPreference="Stop"

$repoDir = $PSScriptRoot

# TODO: fix this
$packagesDir = "e:\nuget"

function download-packages() {
    $nuget = join-path $repoDir "binaries\tools\nuget.exe"

    write-host "Downloadnig nuget.exe"
    & src\download-nuget.ps1 -destPath $nuget -version "3.6.0-beta1"

    write-host "Restoring packages"
    & src\restore.ps1 -nuget $nuget -packagesDir $packagesDir
}

try {
    pushd $repoDir
    
    download-packages

    exit 0
}
catch [exception] {
    write-host $_.Exception
    exit -1
}
finally {
    popd
}
