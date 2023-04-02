# escape=`

# Use the latest Windows Server Core 2022 image.
FROM mcr.microsoft.com/windows/servercore:ltsc2022

ARG PACKAGE_VERSION=1.0.0.0

# Restore the default Windows shell for correct batch processing.
SHELL ["cmd", "/S", "/C"]

RUN `
    # Download the Build Tools bootstrapper.
    curl -SL --output vs_buildtools.exe https://aka.ms/vs/17/release/vs_buildtools.exe `
    `
    # Install Build Tools with the Microsoft.VisualStudio.Workload.AzureBuildTools workload, excluding workloads and components with known issues.
    && (start /w vs_buildtools.exe --quiet --wait --norestart --nocache `
        --installPath "c:\BuildTools\Microsoft Visual Studio\2022\BuildTools" `
        --add Microsoft.NetCore.Component.SDK `
        --remove Microsoft.VisualStudio.Component.Windows10SDK.10240 `
        --remove Microsoft.VisualStudio.Component.Windows10SDK.10586 `
        --remove Microsoft.VisualStudio.Component.Windows10SDK.14393 `
        --remove Microsoft.VisualStudio.Component.Windows81SDK `
        || IF "%ERRORLEVEL%"=="3010" EXIT 0) `
    `
    # Cleanup
    && del /q vs_buildtools.exe

WORKDIR c:\Build
COPY *.ps1 ./
COPY *.nuspec ./
RUN powershell.exe -NoLogo -ExecutionPolicy ByPass .\build-msbuild.ps1 -buildToolsDir 'c:\BuildTools\Microsoft Visual Studio\2022\BuildTools' -packageVersion "$env:PACKAGE_VERSION"

# Define the entry point for the docker container.
# This entry point starts the developer command prompt and launches the PowerShell shell.
# ENTRYPOINT ["%ProgramFiles%\Microsoft Visual Studio\\2022\\BuildTools\\Common7\\Tools\\VsDevCmd.bat", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]