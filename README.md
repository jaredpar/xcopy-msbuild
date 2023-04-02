# XCopy MSbuild

This repo is designed to compose together existing NuGet package assets to create a functional 
version of MSBuild which can be distributed via xcopy / nuget.  

## Build MSBuild

To build the xcopy msbuild you need to have a minimal [Build Tools 2019](https://visualstudio.microsoft.com/downloads/#other) 
installation on your machine. When creating this installation make sure to check **only** the 
following options:

- .Net Desktop Build Tools
- .Net Core 2.1 development tools (right column)
- .Net Framework 4 - 4.6 development tools

Then to build the xcopy NuPkg run the following command:


``` cmd
.\build-msbuild.ps1 -buildToolsDir "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools"
```

That will put the MSBuild output into `binaries\msbuild`.  

## Controlling package name and version

Both of the build scripts accept the following arguments to control the name and version of the package:

- packageName: Name of the package
- packageVersion: Version of the package
