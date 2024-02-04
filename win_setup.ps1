# Bypass execution policy
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrative privileges. Please run it as an administrator."
    Pause
    Exit
}

# Check if winget is already installed
if (-not (Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe")) {
    Write-Host "You need to install winget-cli from the Microsoft Store before running this script, it's the AppInstaller package."
    Exit
}

New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name SystemUsesLightTheme -Value 0 -Type Dword -Force; New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme -Value 0 -Type Dword -Force
# Hides the taskbar news and interests panel
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Value 2
# Hides the taskbar task view button
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name 'ShowTaskViewButton' -Type 'DWord' -Value 0
# Hides the taskbar search button
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search -Name 'SearchboxTaskbarMode' -Type 'DWord' -Value 1
# Finally restart explorer so that the settings can take effect.
taskkill /f /im explorer.exe
Start-Process explorer

# Install NuGet provider if not already installed
if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue -ForceBootstrap)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

# Define an array of winget packages to install
$winget_packages = @(
    "Git.Git",
    "JernejSimoncic.Wget",
    "cURL.cURL",
    "junegunn.fzf",
    "BurntSushi.ripgrep.GNU",
    "Ninja-build.Ninja",
    "Kitware.CMake",
    "JetBrains.ToolBox",
    "Microsoft.VisualStudio.2022.Community",
    "Microsoft.VisualStudioCode",
    "Microsoft.DotNet.SDK.7",
    "Microsoft.DotNet.Runtime.7",
    "Perforce.P4V",
    "Obsidian.Obsidian",
    "Microsoft.PowerToys",
    "Mozilla.Firefox",
    "LLVM.LLVM",
    "Microsoft.WindowsTerminal"
)

# Iterate over the array of package names
foreach ($package in $winget_packages) {
    # Check if the package is already installed
    if (-not (winget list --id $package)) {
        # If the package is not installed, install it
        winget install -e --id $package -y
    } else {
        Write-Host "$package is already installed."
    }
}

# Check if Chocolatey is already installed
if (-not (Test-Path "$env:ProgramData\chocolatey") -or -not (Test-Path "$env:ProgramData\chocolatey\bin\choco.exe")) {
    Write-Host "Installing Chocolatey..."
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    if ($?) {
        Write-Host "Chocolatey installed successfully."
        
        # Reload environment variables
        Write-Host "Reloading environment variables..."
        $env:PATH += ";$env:ProgramData\chocolatey\bin"
        [System.Environment]::SetEnvironmentVariable("PATH", $env:PATH, "Machine")
    } else {
        Write-Host "Failed to install Chocolatey. Please check your internet connection and try again."
        Pause
        Exit
    }
} else {
    Write-Host "Chocolatey is already installed. Upgrading Chocolatey..."
}   

# Install packages from choco_packages.config
Write-Host "Installing packages from packages.config file..."
choco install choco_packages.config -y
choco upgrade all

# Define an array of modules to install from PowerShell Gallery
$gallery_modules = @(
    "Pscx",
    "VSSetup"
)

# Install modules from PowerShell Gallery
Write-Host "Installing modules from PowerShell Gallery..."
foreach ($module in $gallery_modules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Host "Installing module $module..."
        Install-Module $module -Scope CurrentUser -Force
    } else {
        Write-Host "Module $module is already installed. Skipping installation."
    }
}

# Reload environment variables after installing or upgrading packages
Write-Host "Reloading environment variables after installing or upgrading packages..."
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Process)

$git_root = "$($env:SystemDrive)\dev\git"
# Create the root directory if it doesn't exist
if (-not (Test-Path $git_root)) {
    New-Item -ItemType Directory -Path $git_root | Out-Null
}

$git_repos = @(
    "https://github.com/neovim/neovim.git"
)

# Clone Git repositories into the root directory if they don't already exist
foreach ($repo_url in $git_repos) {
    $repo_name = $repo_url.Split("/")[-1].Replace(".git", "")
    $repo_dir = Join-Path -Path $git_root -ChildPath $repo_name

    if (-not (Test-Path $repo_dir)) {
        Write-Host "Cloning repository from $repo_url into $repo_dir..."
        git clone $repo_url $repo_dir
    } else {
        Write-Host "Repository $repo_name already exists in "$git_root", skipping cloning."
    }
}

Write-Host "All git-repos have cloned successfully."

# Build neovim from source nightly
Write-Host "Starting to build neovim nightly from source ..."
Write-Host "Change into the neovim root dir ..."
Set-Location -Path "$git_root\neovim"

Write-Host "Importing VS Vars ..."
# Don't have and don't want VS installed, so we need to run this bat file which will import the vs environment
# We could use pscx to import VSVars, but it requiers an actual VS install, the build-tools are not sufficient.
# Also, the build-tools don't seem to add the cli tools to path, so we're using this absolute path cause were lazy.
$vsdevcmd_abs = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
& $vsdevcmd_abs -arch=x64

Write-Host "Pull latest from master ..."
git pull origin master

Write-Host "Run CMake build ..."
cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=Release
cmake --build .deps --config Release
cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=Release
cmake --build build --config Release

# Write-Host "Update Path"


Write-Host "Neovim has been successfully built from source"