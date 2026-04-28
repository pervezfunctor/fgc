#!/usr/bin/env nu

use std/log
use std/util "path add"

export-env {
  $env.DOT_DIR = ($env.HOME | path join ".fedora-config")
}

export def die [msg: string] {
  log critical $msg
  error make {
    msg: $msg
    label: { text: "fatal error", span: (metadata $msg).span }
  }
}

export def ensure-parent-dir [path: string] {
  let parent = ($path | path dirname)
  if not (dir-exists $parent) {
    log info $"creating directory: ($parent)"
    mkdir $parent
  }
}

export def has-cmd [cmd: string]: nothing -> bool {
  (which $cmd | is-not-empty)
}

export def dir-exists [path: string]: nothing -> bool {
  if not ($path | path exists) { return false }
  ($path | path type) == "dir"
}

export def is-fedora []: nothing -> bool {
  if not ("/etc/redhat-release" | path exists) { return false }
  let content = (open /etc/redhat-release | str downcase)
  $content =~ "fedora"
}

export def sln [src: string, dst: string] {
  if not (($src | path exists) and (($src | path type) != "dir")) {
    log error $"($src) does not exist or is a directory. Skipping linking."
    return
  }

  do -i { ^trash $dst e> /dev/null }
  log info $"linking ($src) -> ($dst)"
  ^ln -sf $src $dst
}

export def "main stow" [package: string] {
  let root = (($env.DOT_DIR | path join $package) | path expand)

  for f in (glob $"($root)/**/*" --no-dir) {
    let src = ($f | path expand)
    let rel = ($src | path relative-to $root)
    let dst = ($env.HOME | path join ".config" $package $rel)
    ensure-parent-dir $dst
    sln $src $dst
  }
}

def group-add [group: string] {
  let groups_output = (^getent group | lines)
  let group_names = ($groups_output | parse "{name}:x:{gid}:{members}" | get name)

  if $group in $group_names {
    log info $"adding user to group ($group)"
    do -i { ^sudo usermod -aG $group $env.USER }
  } else {
    log warning $"($group) group not found, skipping"
  }
}

export def si [packages: list<string>] {
  log info "Installing packages"
  do -i { ^sudo dnf install -y ...$packages }
}

export def touch-files [dir: string, files: list<string>] {
  do -i { mkdir $dir }

  for f in $files {
    let file_path = ($dir | path join $f)
    if not ($file_path | path exists) {
      log info $"creating file ($file_path)"
      touch $file_path
    }
  }
}

def --env bootstrap [] {
  path add $env.DOT_DIR
  path add "/home/linuxbrew/.linuxbrew/bin"

  for p in [
    "bin"
    ".pixi/bin"
    ".local/bin"
    ".opencode/bin"
  ] {
    path add ($env.HOME | path join $p)
  }
}

def "main nvim install" [] {
  pixi global install nvim lazyygit tree-sitter-cli luarocks
  main fonts

  nvim
}

def "main nvim config" [] {
  ^trash ~/.config/nvim
  ^git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim
  ^trash ~/.config/nvim/.git
}

def "main nvim" [] {
  main nvim install
  main nvim config
}

def "main brew" [] {
  if (has-cmd brew) { return }
  log+ "Installing brew"
  http get "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" | bash

  ^brew tap ublue-os/tap
  ^brew install topgrade
}

def "main fonts" [] {
  si ["cascadia-mono-nf-fonts" "cascadia-code-nf-fonts"]
  if (has-cmd brew) {
    brew install font-jetbrains-mono-nerd-font
  }
}

def "main vscode install" [] {
  main fonts

  if not (has-cmd code) {
    log info "Installing vscode"
    do -i {
      ^sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

      let repo = ([
        "[code]"
        "name=Visual Studio Code"
        "baseurl=https://packages.microsoft.com/yumrepos/vscode"
        "enabled=1"
        "autorefresh=1"
        "type=rpm-md"
        "gpgcheck=1"
        "gpgkey=https://packages.microsoft.com/keys/microsoft.asc"
      ] | str join "\n")
      $repo | ^sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
      ^dnf check-update
    }
    si ["code"]
  }
}

def "main vscode config" [] {
  let extensions = [
    "Catppuccin.catppuccin-vsc"
    "mads-hartmann.bash-ide-vscode"
    "TheNuProjectContributors.vscode-nushell-lang"
  ]

  log info "Installing vscode extensions"
  for ext in $extensions {
    do -i { ^code --install-extension $ext }
  }

  main stow "Code"
}

def "main vscode" [] {
  main vscode install
  main vscode config
}

def is-shell-default [shell_path: string] {
  open /etc/passwd
  | lines
  | parse "{user}:{rest}"
  | where user == $env.USER
  | first
  | get rest
  | str ends-with $shell_path
}

def "main fish default" [] {
  log+ "Setting fish as default shell"
  let fish_path = (which fish | get 0.path)
  if not (open /etc/shells | lines | any {|l| $l == $fish_path }) {
    $fish_path | sudo tee -a /etc/shells
  }
  if not (is-shell-default $fish_path) {
    do -i { chsh -s $fish_path $env.USER }
  }
}

def "main fish autostart" [] {
  let rc_file = ".zshrc"
  let rc_path = ($env.HOME | path join $rc_file)
  let marker = "exec fish"

  let snippet = '
# Auto-start fish for interactive shells
if [[ $- == *i* ]] && [[ -z "$FISH_LAUNCHED" ]]; then
  if command -v fish >/dev/null 2>&1; then
    export FISH_LAUNCHED=1
    exec fish || echo "Failed to start fish"
  fi
fi
'

  if not ($rc_path | path exists) {
    error make {msg: $"($rc_file) not found"}
  }
  if not (open $rc_path | str contains $marker) {
    $snippet | save --append $rc_path
    log+ $"Added fish auto-start to ($rc_file)"
  } else {
    log+ $"Fish auto-start already in ($rc_file), skipping"
  }
}

def "main docker" [] {
  if not (has-cmd docker) {
    sudo dnf install -y docker docker-compose
    sudo systemctl enable --now docker.socket
  }
  sudo usermod -aG docker $env.USER
}

def "main fish config" [] {
  log info "Setting up fish config"
  main stow "fish"

  log info "Changing default shell to fish"
  do -i { ^chsh -s (which fish) }
}

def "main fish" [] {
  si ["fish"]
  main fish config
}

def "main kitty" [] {
  # if not (has-cmd $"($env.HOME)/.local/kitty.app/bin/kitty") {
  #   curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
  # }

  si ["kitty"]
  main stow "kitty"
}

def wm-install [] {
  main fonts
  main kitty

  log info "Installing window manager packages"
  si [
    "adw-gtk3-theme"
    "cups-pk-helper"
    "gvfs"
    "gnome-keyring"
    "grim"
    "gvfs-fuse"
    "gvfs-smb"
    "imv"
    "libsecret"
    "mate-polkit"
    "mpv"
    "nautilus"
    "pipewire"
    "pipewire-pulse"
    "pipewire-pulseaudio"
    "qt5ct"
    "qt6ct"
    "slurp"
    "udiskie"
    "udisks2"
    "wireplumber"
    "wl-clipboard"
    "xdg-desktop-portal-gnome"
    "xdg-desktop-portal-gtk"
    "xdg-desktop-portal-wlr"
  ]

  log info "Installing pywal packages"
  if not (has-cmd pipx) { si ["pipx"] }
  ^pipx install pywal
  ^pipx install pywalfox

  let pictures = ($env.HOME | path join "Pictures")
  do -i { mkdir $"($pictures)/Screenshots" }
  do -i { mkdir $"($pictures)/Wallpapers" }

  main stow "xdg-desktop-portal"
}

def "main niri install" [] {
  wm-install

  if (has-cmd dms) and (has-cmd niri) {
    log info "niri and dms are already installed"
    return
  }

  log info "Installing niri and dms"
  ^sudo dnf copr enable -y avengemedia/dms
  ^sudo dnf copr enable -y yalter/niri
  si ["niri" "dms" "cliphist" "dms-greeter"]
  dms greeter enable
}

def "main niri config" [] {
  log info "Setting up niri config"
  main stow "niri"

  let niri_dms = ($env.HOME | path join ".config/niri/dms")
  touch-files $niri_dms ["alttab.kdl" "colors.kdl" "layout.kdl" "wpblur.kdl" "binds.kdl" "cursor.kdl" "outputs.kdl"]

  do -i { ^systemctl --user add-wants niri.service dms }
}

def "main niri" [] {
  main niri install
  main niri config
}

def "main flatpaks" [] {
  if not (has-cmd flatpak) {
    si ["flatpak"]
  }

  log info "Adding flathub remote"
  ^flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo --user

  let flatpaks = [
    "com.github.tchx84.Flatseal"
    "app.zen_browser.zen"
    "md.obsidian.Obsidian"
    org.gnome.Papers
  ]

  for pkg in $flatpaks {
    log info $"Installing ($pkg)"
    do -i { ^flatpak --user install -y flathub $pkg }
  }
}

def "main virt config" [] {
  if not (has-cmd virsh) {
    log error "install libvirt first with `setup.nu virt install`"
    return
  }

  log info "Setting up libvirt"

  for group in ["libvirt" "qemu" "libvirt-qemu" "kvm" "libvirtd"] {
    group-add $group
  }

  log info "Enabling libvirtd service"
  do -i { ^sudo systemctl enable --now libvirtd }
  do -i { ^sudo virsh net-autostart default }
  log info "Enabling authselect with-libvirt feature"
  do -i {
    if (has-cmd authselect) {
      ^sudo authselect enable-feature with-libvirt
    }
  }
}

def "main virt install" [] {
  log info "Installing virt-manager"

  si [
    "dnsmasq"
    "libvirt"
    "libvirt-nss"
    "qemu-img"
    "qemu-tools"
    "libisoinfo"
    "osinfo-db"
    "osinfo-db-tools"
    "libguestfs-tools"
    "guestfs-tools"
    "swtpm"
    "virt-install"
    "virt-manager"
    "virt-viewer"
  ]
}

def "main virt" [] {
  si ["distrobox"]
  main virt install
  main virt config
}

def "main opencode" [] {
  if (has-cmd opencode) {
    log info "opencode is already installed"
    return
  }

  log info "Installing opencode"
  ^curl -fsSL https://opencode.ai/install | bash
}

def "main desktop" [] {
  main virt
  main flatpaks
  main brew
  main niri
}

def "main zed" [] {
  if (has-cmd zed) {
    log info "zed is already installed"
    return
  }

  log info "Installing zed"
  curl -f https://zed.dev/install.sh | sh

  main stow "zed"
}

let COMMANDS = {
  niri: {
    desc: "Install and configure niri WM"
    run: {|| main niri }
  }
  vscode: {
    desc: "Install vscode and extensions"
    run: {|| main vscode }
  }
  virt: {
    desc: "Install and configure virt-manager/libvirt"
    run: {|| main virt }
  }
  docker: {
    desc: "Install and configure Docker(from fedora repo)"
    run: {|| main docker }
  }
  flatpaks: {
    desc: "Install flatpak applications(zen browser, obsidian)"
    run: {|| main flatpaks }
  }
  brew: {
    desc: "Install Homebrew"
    run: {|| main brew }
  }
  zed: {
    desc: "Install and configure Zed editor"
    run: {|| main zed }
  }
  nvim: {
    desc: "Install and configure(Astro) Neovim"
    run: {|| main nvim }
  }
}

def commands [] {
  $COMMANDS | transpose name value
}

def options [] {
  commands | get name
}

def run-command [cmd: string] {
  let key = ($cmd | str trim)
  let action = (
    commands
    | where name == $key
    | get value
    | first
  )

  if ($action | is-empty) {
    log warning $"Unknown command: ($key)"
    return
  }

  do $action.run
}

const DEFAULT_INSTALL = []

def gum-select-install [] {
  if not (has-cmd gum) {
    die "gum is required for interactive selection"
  }

  let defaults = ($DEFAULT_INSTALL | str join ",")

  options
  | str join "\n"
  | ^gum choose --no-limit --selected $defaults
  | lines
  | each {|cmd| run-command ($cmd | str trim) }
  | ignore
}

def "main help" [] {
  print "Usage:"
  print "  setup.nu"
  print "  setup.nu help"
  print "  setup.nu <command>"
  print ""
  print "Commands:"
  print "  help             Show this help message"
  print "  desktop          Configure desktop environment(niri, virt, brew, apps)"
  print "  stow <package>   Symlink a config package into ~/.config"

  commands | each {|row| print $"  ($row.name | fill -w 16) ($row.value.desc)" }

  print ""
  print "  opencode         Install opencode(AI)"
  print "  virt config      Configure libvirt"
  print "  kitty            Install and Configure Kitty terminal"
  print "  fish             Install and configure fish shell"
  print ""
}

def "main update" [] {
  log info "Updating packages"
  ^sudo dnf update -y
}


def check-commands [...cmds: string]: nothing -> bool {
  mut result = true
  for cmd in $cmds {
    if not (has-cmd $cmd) {
      warn+ $"($cmd) not available"
      result := false
    }
  }
  $result
}

def checks [] {
  if (has-cmd rpm-ostree) {
    die "fedora atomic not supported. Quitting."
  }

  if not (check-commands "gum" "trash" "git" "pixi") {
    die "Required commands not available. Quitting."
  }

  if not (is-fedora) {
    die "Only Fedora supported. Quitting."
  }
}

def "main default" [] {
  checks
  bootstrap
  main update
}

def main [] {
  main default
  gum-select-install
}
