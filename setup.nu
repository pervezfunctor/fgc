#!/usr/bin/env nu

use std/log
use std/util "path add"

export-env {
  $env.DOT_DIR = ($env.HOME | path join ".fedora-niri-config")
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

def file-or-link-exists [p: path]: nothing -> bool {
    if not ($p | path exists) { return false }
    let t = ($p | path type)
    $t == "file" or $t == "symlink"
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

  if (file-or-link-exists $dst) {
    if (has-cmd trash) {
      ^trash $dst
    } else {
      rm -f $dst
    }
  }

  log info $"linking ($src) -> ($dst)"
  ^ln -s $src $dst
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

export def "main brew" [] {
  if (has-cmd brew) { return }
  log+ "Installing brew"
  http get "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" | bash

  ^brew tap ublue-os/tap
  ^brew install topgrade
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

def "main fonts" [] {
  si ["cascadia-mono-nf-fonts" "cascadia-code-nf-fonts"]
}

def "main vscode" [] {
  main vscode install
  main vscode config
}

def "main docker" [] {
  if not (has-cmd docker) {
    sudo dnf install -y docker docker-compose
    sudo systemctl enable --now docker.socket
  }
  sudo usermod -aG docker $env.USER
}

def wm-install [] {
  main fonts
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
    "kitty"
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

  main stow "kitty"
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

def "main fish" [] {
  si ["fish"]
  main stow "fish"
  do -i { ^sudo chsh -s /usr/bin/fish $env.USER }
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
  main niri
}

def "main help" [] {
  print "Usage:"
  print "  setup.nu"
  print "  setup.nu help"
  print "  setup.nu <command>"
  print ""
  print "Commands:"
  print "  help             Show this help message"
  print "  desktop          Run desktop setup (virt, flatpaks, niri)"
  print ""
  print "  niri             Install and configure niri WM"
  print "  niri install     Install niri, dms, and related packages"
  print "  niri config      Apply niri config only"
  print ""
  print "  flatpaks         Install flatpak applications"
  print ""
  print "  vscode           Install vscode and extensions"
  print "  vscode install   Install vscode only"
  print "  vscode config    Install vscode extensions/settings only"
  print ""
  print "  virt             Install and configure virt-manager/libvirt"
  print "  virt install     Install virt packages only"
  print "  virt config      Configure libvirt only"
  print ""
  print "  docker           Install and configure docker"
  print "  brew             Install and configure homebrew for linux"
  print "  fish             Install and configure fish shell"
  print "  opencode         Install opencode AI coding agent"
  print ""
  print "  stow <package>   Symlink a config package into ~/.config"
  print ""
}

def "main update" [] {
  log info "Updating packages"
  ^sudo dnf update -y
}

def checks [] {
  if (has-cmd rpm-ostree) {
    die "fedora atomic not supported. Quitting."
  }
  if not (has-cmd trash) { si ["trash-cli"] }
  if not (is-fedora) {
    die "Only Fedora supported. Quitting."
  }
}

def main [] {
  checks
  bootstrap
  main update
  main desktop
}
