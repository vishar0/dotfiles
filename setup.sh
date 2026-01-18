#!/usr/bin/env zsh

# Requirements: iterm2, zsh

# Change default shell to zsh
# chsh -s $(which zsh)

MAC_DEPS=(
  python
  tmux
  bat           # cat++
  fd            # find++
  neovim        # vim++
  ripgrep       # grep++
  fzf           # fuzzy finder - https://github.com/junegunn/fzf
  tree          # for fzf previews of dir trees
  git-delta     # improved diff viz - https://github.com/dandavison/delta
  clang-format
  gh
  openssl
  wget
  reattach-to-user-namespace  # tmux access to clipboard: https://blog.carbonfive.com/copying-and-pasting-with-tmux-2-4
)

LINUX_DEPS=(
  bat
  fd-find
  ripgrep
  git-delta
)

BIN_DIR=~/bin

VSCODE_FORKS=(
  Code
  Cursor
  Antigravity
)

VSCODE_FORKS_CLI=(
  code
  cursor
  agy
)

function install_homebrew() {
  if ! command -v brew &>/dev/null; then
    echo "\n#### Installing homebrew ####\n"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "\n#### Homebrew already installed ####\n"
  fi
}

function brew_install_or_upgrade() {
  if brew ls --versions "$1"; then
    brew upgrade "$1"
  else
    brew install "$1"
  fi
}

function install_mac_deps() {
  # Install brew dependencies if on mac
  if [ "$(uname -s)" = "Darwin" ]; then
    install_homebrew

    echo "\n#### Installing mac dependencies ####\n"
    brew update || true
    for dep in ${MAC_DEPS}; do
      brew_install_or_upgrade ${dep} || true
    done
    $(brew --prefix)/opt/fzf/install --all || true  # fzf key-bindings and fuzzy completion
  fi
}

function install_linux_deps() {
  if [ "$(uname -s)" = "Linux" ]; then
    echo "\n#### Installing linux dependencies ####\n"
    sudo apt update
    for dep in ${LINUX_DEPS}; do
      sudo apt install -y ${dep} || true
    done
  fi
}

function install_pip_deps() {
  echo "\n#### Installing pip dependencies ####\n"
  pip3 install --upgrade \
     cpplint \
     numpy \
     pandas \
     pdbpp \
     pre-commit \
     ptpython \
     tabcompletion \
     tabulate \
     wandb \
     || true
}

function install_deps() {
  install_mac_deps
  install_linux_deps
  install_pip_deps

  echo "\n#### Installing on-my-zsh ####\n"
  # Install oh-my-zsh into current dir. We'll symlink later to homedir.
  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | ZSH=.oh-my-zsh sh || true

  echo "\n#### Installing antigen ####\n"
  # Install antigen (for easier third-party plugin management than oh-my-zsh) into current dir.
  # We'll symlink later to homedir.
  curl -L git.io/antigen > .antigen.zsh

  echo "\n#### Installing uv ####\n"
  curl -LsSf https://astral.sh/uv/install.sh | sh

  echo "\n#### Installing claude code ####\n"
  curl -fsSL https://claude.ai/install.sh | bash
}

function symlink_dotfiles() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: ${0} <target_dir>"
    return
  fi

  echo "\n#### Setting up symlinks ####\n"

  target_dir="${1}"

  # Symlink dotfiles to target_dir
  for f in $(ls -a | grep '^\.'); do
    if ! [[ ($f == .)  || ($f == ..) || ($f =~ "^\.git.*") || ($f =~ "\.sw.*") ]]; then
      echo "Symlink: ${target_dir}/${f} -> $(pwd)/${f}"
      ln -sf $(pwd)/${f} ${target_dir}/
    fi
  done
}

function symlink_vscode_configs() {
  if [ "$(uname -s)" = "Darwin" ]; then
    config_base_dir="${HOME}/Library/Application Support"
  else
    config_base_dir="${HOME}/.config"
  fi

  for editor in "${VSCODE_FORKS[@]}"; do
    config_dir="${config_base_dir}/${editor}/User"
    if [ -d "${config_dir}" ]; then
      echo "\n#### Symlinking ${editor} configs ####\n"
      echo "Symlink: ${config_dir}/settings.json -> $(pwd)/vscode/settings.json"
      ln -sf "$(pwd)/vscode/settings.json" "${config_dir}/settings.json"
      echo "Symlink: ${config_dir}/keybindings.json -> $(pwd)/vscode/keybindings.json"
      ln -sf "$(pwd)/vscode/keybindings.json" "${config_dir}/keybindings.json"
    fi
  done
}

function install_vscode_extensions() {
  for cli in "${VSCODE_FORKS_CLI[@]}"; do
    if command -v "${cli}" &>/dev/null; then
      echo "\n#### Installing ${cli} extensions ####\n"
      cat vscode/extensions.txt | xargs -L 1 -I {} "${cli}" --install-extension {}
    fi
  done
}


function download_binary() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: ${0} <release_url.tar.gz> [<num_leading_path_elements_to_skip>]"
    return
  fi

  url="${1}"
  strip_components="${2:-0}"

  echo "Extracting ${url} to ${BIN_DIR}"
  mkdir -p ${BIN_DIR}
  wget -qO- ${url} | tar xz - -C ${BIN_DIR}/ --strip-components=${strip_components}
}

git submodule update --init --recursive --remote
install_deps
symlink_dotfiles ~  # Symlink dotfiles to homedir
symlink_vscode_configs
install_vscode_extensions

git config --global user.email vish@flourishlabs.ai
git config --global user.name "Vish Sivakumar"
git config --global include.path ~/.delta.gitconfig  # git-delta config

echo "\n#### Done setting up dotfiles! ####\n"
