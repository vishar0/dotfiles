###################################################
#
# Preamble
#
###################################################

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ $OSTYPE == darwin* ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

###################################################
#
# Environment variables
#
###################################################

export PATH="$PATH:$HOME/bin:$HOME/local/bin:$HOME/.local/bin"
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

export EDITOR=/usr/bin/vim
export VISUAL=/usr/bin/vim
export HISTSIZE=130000
export HISTFILESIZE=-1
export PYTHONSTARTUP="$HOME/.pythonrc"

###################################################
#
# Util functions
#
###################################################
#
# Check for the availability of a command.
# Usage: has-command <command_name>
function has-command() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: ${0} <command_name>"
    return
  fi

  cmd="${1}"

  command -v ${cmd} > /dev/null 2>&1
}



# Search and replace using rg and sed. Supports searching by regex.
# Usage: rgr <search_pattern> <replacement_text>
function rgr() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: ${0} <search_pattern> <replacement_text>"
    return
  fi

  pattern="${1}"
  replacement="${2}"

  # Search and replace inplace, backing up original files
  # with the extension .rgr_backup
  BACKUP_EXT=.rgr_backup
  rg "${pattern}" -l | xargs sed -i"${BACKUP_EXT}" "s/${pattern}/${replacement}/g"

  # Delete backups. We could use fd here to list backup files, but
  # sticking to rg for platform compatibility.
  rg --files -g "*${BACKUP_EXT}" | xargs rm
}


# Search and delete lines containing regex pattern using rg and sed.
# Usage: rgd <search_pattern>
function rgd() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: ${0} <search_pattern>"
    return
  fi

  pattern="${1}"

  # Search and delete lines with matches inplace, backing up original files
  # with the extension .rgr_backup
  BACKUP_EXT=.rgd_backup
  rg "${pattern}" -l | xargs sed -i"${BACKUP_EXT}" "/${pattern}/d"

  # Delete backups. We could use fd here to list backup files, but
  # sticking to rg for platform compatibility.
  rg --files -g "*${BACKUP_EXT}" | xargs rm
}


# Fix hotspot not working due to carriers throttling tethered traffic.
# Usage: hotspot <on|off>
function hotspot() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: ${0} <on|off>"
    return
  fi

  on_or_off="${1}"

  if [ "${on_or_off}" = "on" ]; then
    # Increase TTL from 64 to 65 to add an extra hop. With the default TTL of 64
    # packet originating from tethered laptop will have a TTL of 63 when it gets
    # to the phone. Carriers use this to distinguish phone traffic from hotspot
    # and throttle. Bump up TTL to 65 to get around this.
    sudo sysctl net.inet.ip.ttl=65
    # Also disable ipv6 because the setting for TTL on IPv6 (known as HLIM)
    # is apparently not honored by Mac OS.
    sudo networksetup -setv6off "Wi-Fi"
    echo "Hotspot mode enabled"
  else
    # Revert hotspot unfix and turn back ipv6 on when on wifi
    sudo sysctl net.inet.ip.ttl=64
    sudo networksetup -setv6automatic "Wi-Fi"
    echo "Back on wifi mode"
  fi
}


# Enable `fwdproxy-config` aliases when on devserver.
# Usage: fwdproxy <on|off> <all|git|curl|wget|...>
function fwdproxy() {
  # Only proceed if fwdproxy-config command is found. Otherwise,
  # not on devserver and no need for proxy.
  if ! has-command fwdproxy-config; then
    return
  fi

  if [ "$#" -ne 2 ]; then
    echo "Usage: ${0} <on|off> <command>"
    return
  fi

  on_or_off="${1}"
  cmd="${2}"

  CMDS=(git hg curl wget ssh java)
  if [[ "${cmd}" == "all" ]]; then
    cmds=("${CMDS[@]}")
  elif [[ "${CMDS[*]} " =~ "${cmd}" ]]; then
    cmds=("${cmd}")
  else
    echo "Unknown command ${cmd}, must be either 'all' or one of [${CMDS}]"
    return
  fi

  if [ "${on_or_off}" = "on" ]; then
    # Set aliases with fwdproxy-config
    for cmd in "${cmds[@]}"; do
      alias "${cmd}=${cmd} $(fwdproxy-config ${cmd})"
    done
  else
    # Unset aliases
    for cmd in "${cmds[@]}"; do
      unalias "${cmd}"
    done
  fi
}


# Encrypt or decrypt a file with openssl
OPENSSL_CMD="openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100000"
function enc() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: ${0} <in_file> [<out_file>]"
    return
  fi
  
  in_file="${1}"
  out_file="${2}"
  if [ -z "${out_file}" ]; then
    out_file="${in_file}.enc"
  fi

  cmd="${OPENSSL_CMD} -in ${in_file} -out ${out_file}"
  echo "${cmd}"
  eval "${cmd}"
}
function dec() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: ${0} <in_file> <out_file>"
    return
  fi

  in_file="${1}"
  out_file="${2}"

  cmd="${OPENSSL_CMD} -in ${in_file} -out ${out_file} -d"
  echo "${cmd}"
  eval "${cmd}"
}


# fzf + git: https://polothy.github.io/post/2019-08-19-fzf-git-checkout/
function in_git_repo() {
  git rev-parse HEAD > /dev/null 2>&1
}
function fzf-git-branch() {
  # Return early if not in a git repo
  in_git_repo || return

  git branch --all --color=always |
    grep -v HEAD |
    fzf --preview 'git log -n 50 --color=always --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed "s/.* //" <<< {})' |
    sed "s/.* //"
}
fzf-git-switch() {
  # Return early if not in a git repo
  in_git_repo || return

  # If branch name is provided, no need to invoke `fzf-git-branch`
  if ! [ $# -eq 0 ]; then
     git switch "$@"
     return
   fi

  local branch

  branch=$(fzf-git-branch)
  if [[ "$branch" = "" ]]; then
      echo "No branch selected"
      return
  fi

  # If branch name starts with 'remotes/' then it is a remote branch. By
  # using --track and a remote branch name, it is the same as:
  # git switch -c branchName --track origin/branchName
  if [[ "$branch" = 'remotes/'* ]]; then
      git switch --track $branch
  else
      git switch $branch;
  fi
}


###################################################
#
# Oh My Zsh
#
###################################################

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=()  # Ignore, taken over by antigen below

source $ZSH/oh-my-zsh.sh

###################################################
#
# Conda
#
###################################################

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/vish/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/vish/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/vish/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/vish/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

has-command conda && eval "$(conda shell.zsh hook)"


###################################################
#
# Antigen
#
###################################################

# Enable fwdproxy-config aliases for all commands to connect to the internet
# when on devserver so we can fetch the necessary plugins at startup.
# This is reverted at the end of this file.
fwdproxy on all

source ~/.antigen.zsh
antigen use oh-my-zsh

# Theme
# antigen theme jreese
#
# The following two must be enabled together:
# antigen bundle mafredri/zsh-async
# antigen bundle sindresorhus/pure
#
antigen theme romkatv/powerlevel10k

# Plugins from oh-my-zsh (https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins)
antigen bundle git
antigen bundle colored-man-pages
antigen bundle web-search
antigen bundle vi-mode

# Custom/third-party plugins
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-syntax-highlighting

# Plugin settings
# zsh-autosuggestions (prefer tab completion suggestions first and then history)
# export ZSH_AUTOSUGGEST_STRATEGY=(completion history)

# Apply
antigen apply

# All done. Unset fwdproxy-config aliases if set.
fwdproxy off all

###################################################
#
# Plugin settings
#
###################################################

# antigen theme romkatv/powerlevel10k.
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[ -f ~/.p10k.zsh ] && source ~/.p10k.zsh


# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# fzf command order of preference based on availability: fd > ripgrep > find (default)
if has-command fd; then
  export FZF_DEFAULT_COMMAND='fd --type file --color=always'
elif has-command rg; then
  export FZF_DEFAULT_COMMAND='rg --files --color=always'
fi
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"

# CTRL+d and CTRL+u for navigating fzf results, color/display/preview settings, etc.
export FZF_DEFAULT_OPTS="
--bind=ctrl-d:down,ctrl-u:up,?:toggle-preview \
--height=40% \
--layout=reverse \
--ansi \
--preview '(
    [[ -f {} ]] && (bat --style=numbers --color=always --line-range :500 {} || cat {})) \
    || ([[ -d {} ]] && (tree -C {} | less)) \
    || echo {} 2> /dev/null | head -200' \
--preview-window=right,60% \
"

# bat, if installed, is used by fzf to prettify previews
export BAT_CONFIG_PATH="$HOME/.bat.conf"


###################################################
#
# Aliases
#
###################################################

alias woman='man'  # For Silky
alias sudo='sudo '
has-command nvim && alias v='nvim' || alias v='vim'
alias l='ls -lh'
alias la='ls -lha'
alias py='python'

# cd
alias wrk='cd ~/work'
alias lcl='cd ~/local'
alias jnk='cd ~/junk'
alias gdrive='cd ~/gdrive'
alias zk='cd ~/gdrive/zettelkasten'
alias mlzk='cd ~/gdrive/zettelkasten/ml-zettelkasten'
alias gtd='cd ~/gdrive/zettelkasten/gtd'
alias docs='cd ~/gdrive/docs'
alias fbs='cd ~/fbsource'
alias fbc='cd ~/fbsource/fbcode'

# git
alias gd='git diff'
alias gc='git commit -a -v'
alias ga='git commit -a -v --amend'
alias gaa='git add --all'
alias gaad='git add --all --dry-run'
alias gs='git status'
alias gst='git stash'
alias gsh='git show'
alias gl='git log --graph --decorate --oneline'
alias gpr='git pull --rebase'
alias gpro='git pull --rebase origin'
alias gprom='git pull --rebase origin main'
alias gprum='git pull --rebase upstream main'
alias gf='git fetch'
alias gfo='git fetch origin'
alias grs='git restore'
alias gbm='git switch $(git_main_branch)'  # git branch main
alias gbn='git switch -c'  # git branch new
has-command fzf && alias gbl='fzf-git-branch' || alias gbl='git branch -vv'  # git branch list
has-command fzf && alias gb='fzf-git-switch' || alias gb='git switch'  # git branch (switch to existing)

# hg
alias hd='hg diff'
alias hc='hg commit'
alias ha='hg commit --amend'
alias hb='hg bookmarks'
alias hsh='hg show'
function hp() {
  hg pull
  hg update $1
  hg rebase -d main
}

# tmux
alias tmx='tmux attach -d || tmux'  # Unique view: Attach to existing, detach old view
alias tmxa='tmux attach || tmux'  # Multiple views: Attach to existing, keep both views

# conda
alias ca='conda activate'
alias cda='conda deactivate'
alias cenv='conda env'

# aws
alias s3ls='aws s3 ls --summarize --human-readable --recursive'
alias s3cp='aws s3 cp'
alias s3cpr='aws s3 cp --recursive'
alias s3put='aws s3api put-object'  # s3put --bucket <bucket> --key <path>

# Plugins and extras
has-command bat && alias cat='bat'  # s/cat/bat if bat is installed
has-command exa && alias ls='exa'  # s/ls/exa if exa is installed
has-command exa && alias lt='exa --tree'
alias goog='google'  # zsh web-search plugin

# Alias to mosh into a jumphost and then ssh as mosh doesn't support ProxyJump
alias moshjmp='mosh -6 jmp -n ssh'

# meta dev
alias devc='dev connect --mosh'
alias devl='dev list'
alias devr='dev release'


###################################################
#
# Source additional scripts
#
###################################################

# FB-specific stuff
[ -f ~/.fb.zshrc ] && source ~/.fb.zshrc
