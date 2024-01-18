#!/bin/zsh

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    # install homebre
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew_formulaes = (
    "git",
    "wget",
    "curl",
    "eza",
    "fzf",
    "yabai",
    "skhd",
    "ripgrep",
    "ninja",
)

brew_casks = (
    "kitty",
    "maccy",
    "raycast",
)

# Install Homebrew packages
for formulae in $brew_formulaes; do
    if ! brew list $formulae &> /dev/null; then
        brew install $formulae
    fi
done

# Install Homebrew casks
for cask in $brew_casks; do
    if ! brew list --cask $cask &> /dev/null; then
        brew install --cask $cask
    fi
done

git_repos = (
    "https://github.com/neovim/neovim.git",
    "https://github.com/LarssonMartin1998/.dotfiles.git",
)

git_dir = "$HOME/dev/git" 
mkdir -p $git_dir

# Clone git repos
for repo in $git_repos; do
    repo_name = $(basename $repo)
    
    # Check if repo is already cloned
    if [ ! -d "$git_dir/$repo_name" ]; then
        git clone $repo $git_dir/$repo_name
    fi
done

# Install neovim
if ! command -v nvim &> /dev/null; then
    cd $git_dir/neovim
    make CMAKE_BUILD_TYPE=Release
    cmake CMAKE_INSTALL_PREFIX=$HOME/local/nvim install
fi

# Setup dotfiles
./$git_dir/.dotfiles/upgrades.sh
