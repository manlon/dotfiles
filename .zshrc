# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#ZSH_THEME="robbyrussell"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
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

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.


#. /opt/homebrew/opt/asdf/libexec/asdf.sh
# PATH=$(dirname -- $(asdf which virtualenvwrapper_lazy.sh)):$PATH \
#
PATH="$HOME/.local/share/mise/installs/python/latest/bin:$PATH"

if [[ -z "${ZED_TERM}" && -z "${VSCODE_INJECTION}" ]]; then
    plugins=(git virtualenvwrapper)
else
    plugins=(git)
fi

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

export RUBY_CONFIGURE_OPTS="--with-zlib-dir=$(brew --prefix zlib) --with-openssl-dir=$(brew --prefix openssl@3) --with-readline-dir=$(brew --prefix readline) --with-libyaml-dir=$(brew --prefix libyaml)"
export RUBY_CFLAGS="-Wno-error=implicit-function-declaration"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


# bun completions
[ -s "/Users/hanlon/.bun/_bun" ] && source "/Users/hanlon/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export ERL_AFLAGS="-kernel shell_history enabled"


test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

  . /opt/homebrew/etc/profile.d/z.sh

alias cat=bat
alias exa=eza
alias lt='eza -al -snewest'
alias ll='eza -l'
eval "$(atuin init zsh)"

eval "$(mise activate zsh)"

alias bnp='bat --no-paging'

alias jjd='jj diff'
alias jjdc="jj diff -r cur"
alias jjds="jj diff -s -r cur"
alias jjf='jj git fetch'
alias jjr='jj rebase -b @ -d main'
alias jjb="jj log -r 'ancestors(@) & bookmarks()' --limit 1 -T 'bookmarks.map(|b| b.name()).join(\" \")' --no-graph"
alias jjsc="jj show cur"
alias jjrm="jj rebase -o main"
alias jjlm="jj log -r mine"
alias jjsa="/Users/hanlon/.local/bin/jj-snapshot-all"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
autoload -Uz compinit && compinit

export EDITOR=vim

# Added by Antigravity
export PATH="/Users/hanlon/.antigravity/antigravity/bin:$PATH"


# Create a new worktree and branch from within current git directory or worktree.
gwa() {
  if [[ -z "$1" ]]; then
    echo "Usage: gwa [branch name]"
    return 1
  fi

  local branch="$1"
  local base="$(basename "$PWD")"
  local root="${base%%--*}"  # Extract base project name (works from main repo or worktree)
  local safe_branch="${branch//\//-}"
  local wt_path="../${root}--${safe_branch}"
  local source_dir="$PWD"

  git worktree add -b "$branch" "$wt_path"

  # Copy priv/repo if it exists (for Phoenix dev setup)
  if [[ -d "$source_dir/priv/repo" ]]; then
    cp -r "$source_dir/priv/repo/." "$wt_path/priv/repo/"
  fi

  mise trust "$wt_path"
  cd "$wt_path"
}


# Rename current worktree and its branch.
gwr() {
  if [[ -z "$1" ]]; then
    echo "Usage: gwr [new branch name]"
    return 1
  fi

  local new_branch="$1"
  local cwd="$(pwd)"
  local worktree="$(basename "$cwd")"
  local root="${worktree%%--*}"

  # Get current branch name
  local old_branch="$(git symbolic-ref --short HEAD 2>/dev/null)"

  if [[ -z "$old_branch" ]]; then
    echo "Not on a branch"
    return 1
  fi

  # Check we're in a worktree (not the main repo)
  if [[ "$root" == "$worktree" ]]; then
    echo "Not a worktree"
    return 1
  fi

  # Create safe branch name for directory (replace / with -)
  local safe_branch="${new_branch//\//-}"
  local new_wt_path="$(dirname "$cwd")/${root}--${safe_branch}"

  # Rename the branch
  git branch -m "$old_branch" "$new_branch"

  # Move the directory and repair worktree references
  cd ..
  mv "$cwd" "$new_wt_path"
  cd "$new_wt_path"
  git worktree repair
}


# Remove worktree and branch from within active worktree directory.
gwd() {
  if gum confirm "Remove worktree and branch?"; then
    local cwd worktree branch root

    cwd="$(pwd)"
    worktree="$(basename "$cwd")"

    # Get actual branch name from git (handles slashes correctly)
    branch="$(git symbolic-ref --short HEAD 2>/dev/null)"

    if [[ -z "$branch" ]]; then
      echo "Not on a branch"
      return 1
    fi

    root="${worktree%%--*}"

    if [[ "$root" != "$worktree" ]]; then
      cd "../$root"
      git worktree remove "$cwd" --force  # Use absolute path
      git branch -D "$branch"
    else
      echo "not a worktree"
      return 1
    fi
  fi
}
