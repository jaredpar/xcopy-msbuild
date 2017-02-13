param ([string]$msbuild = $(throw "Need a path for msbuild.exe"))
set-strictmode -version 2.0
$ErrorActionPreference="Stop"

try
{
    $projDir = join-path $PSScriptRoot "..\projs"
    $testList = @(
        "CSharpDesktopConsole\CSharpDesktopConsole.sln"
        "BasicDesktopConsole\BasicDesktopConsole.sln"
    )

    $exitCode = 0
    write-host "Running tests"
    foreach ($projName in $testList) { 
        $projPath = join-path $projDir $projName
        write-host -NoNewLine "`t$projName "
        $output = & $msbuild /v:m $projPath

        if ($?) {
            write-host "passed"
        }
        else {
            write-host "FAILED"
            write-host $output
            $exitCode = 1
        }
    }

    gps VBCSCompiler -ErrorAction SilentlyContinue | kill
    exit $exitCode
}
catch [exception]
{
    write-host $_.Exception
    exit -1
}
