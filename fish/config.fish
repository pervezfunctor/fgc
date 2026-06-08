set -x MANROFFOPT "-c"
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

if test -f ~/.fish_profile
  source ~/.fish_profile
end

set -gx DOT_DIR $HOME/.fgc
if not set -q XDG_DATA_DIRS
    set -gx XDG_DATA_DIRS /usr/local/share /usr/share
end
set -gx XDG_DATA_DIRS $HOME/.local/share/flatpak/exports/share $XDG_DATA_DIRS

fish_add_path --global --move \
  /home/linuxbrew/.linuxbrew/bin \
  $HOME/.local/share/flatpak/exports/bin \
  $DOT_DIR/scripts \
  $HOME/bin \
  $HOME/.pixi/bin \
  $HOME/.local/bin \
  $HOME/.cargo/bin

function has_cmd
  type -q $argv[1]
end

if ! status is-interactive
  return
end

function fish_greeting
end

alias gs 'git stash'
alias gp 'git push'
alias gb 'git branch'
alias gbc 'git checkout -b'
alias gsl 'git stash list'
alias gst 'git status'
alias gsu 'git status -u'
alias gcan 'git commit --amend --no-edit'
alias gsa 'git stash apply'
alias gfm 'git pull'
alias gcm 'git commit -m'
alias gia 'git add'
alias gco 'git checkout'
alias gpr 'git stash -u && git pull --rebase && git stash apply'

function git-tree
    git status --short | awk '{print $2}' | tree --fromfile
end

if has_cmd gh
  alias gh-refresh 'gh auth refresh -h github.com'
end

if has_cmd flatpak
  alias fpi 'flatpak install --user flathub'
  alias fpr 'flatpak remove --user'
  alias fps 'flatpak search'
  alias fpu 'flatpak update --user'
end

alias i 'sudo dnf install -y'
alias r 'sudo dnf remove'
alias s 'dnf search'
alias u 'sudo dnf update --refresh'

if has_cmd eza
    alias ls  'eza --icons --group-directories-first'
end

if has_cmd uvx
  alias uv-marimo-standalone 'uvx --with pyzmq --from "marimo[sandbox]" marimo edit --sandbox'
end

if has_cmd zed
  set -gx VISUAL zed
else if has_cmd zeditor
  set -gx VISUAL zeditor
else if has_cmd code
  set -gx VISUAL code
else if has_cmd antigravity
  set -gx VISUAL antigravity
end

if has_cmd nvim
  set -gx EDITOR nvim
else if has_cmd micro
  set -gx EDITOR micro
else if has_cmd emacs
  set -gx EDITOR emacs
else if has_cmd vim
  set -gx EDITOR vim
else
  set -gx EDITOR $VISUAL
end

if test -f ~/.fgc/fish/local.fish
  source ~/.fgc/fish/local.fish
end

if test -f ~/.vite-plus/env.fish
  source ~/.vite-plus/env.fish
end

if test -n "$FISH_SIMPLE"
    return
end

if has_cmd zoxide
    zoxide init fish | source
end

if has_cmd fzf
    fzf --fish | source
end

if has_cmd starship
    starship init fish | source
end

if has_cmd carapace
    set -gx CARAPACE_BRIDGES 'zsh,fish,bash,inshellisense' # optional
    carapace _carapace | source
end
