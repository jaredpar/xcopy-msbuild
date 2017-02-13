# XCopy MSbuild

This repo is designed to compose together existing NuGet package assets to create a functional 
version of MSBuild which can be distributed via xcopy. 

## Build and test

To build the xcopy msbuild simple run the following command

``` cmd
.\build.ps1
```

That will put the MSBuild output into `binaries\msbuild`.  

To run tests use the following command

``` cmd
.\build.ps1 -test
```
