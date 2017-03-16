# XCopy MSbuild

This repo is designed to compose together existing NuGet package assets to create a functional 
version of MSBuild which can be distributed via xcopy / nuget.  

## Build MSBuild

To build the xcopy msbuild simple run the following command

``` cmd
.\build-msbuild.ps1 -msbuildDir <path to msbuild>
```

That will put the MSBuild output into `binaries\msbuild`.  

To run tests use the following command

``` cmd
.\build.ps1 -test
```

## Build Reference Assemblies

In order to build most .NET projects MSBuild will need the .NET Reference assemblies.  These are a separate component from MSBuild and hence this repo produces a separate package for them.  To produce this packaeg run the following command.

``` cmd
.\build-reference-assemblies.ps1
```

Note that MSBuild needs to be told of their location via `TargetFrameworkRootPath`.  This can be specified on the command line or via an environment variable:

``` cmd
msbuild /p:TargetFrameworkRootPath=path\to\refassemblynuget
```

## Controlling package name and version

Both of the build scripts accept the following arguments to control the name and version of the package:

- packageName: Name of the package
- packageVersion: Version of the package
