#!/usr/bin/env nu

use std/log
use std/util "path add"

export-env {
  $env.DOT_DIR = ($env.HOME | path join ".fedora-config")
}

def is-atomic []: nothing -> bool {
  has-cmd rpm-ostree
}

def die [msg: string] {
  log critical $msg
  error make {
    msg: $msg
    label: { text: "fatal error", span: (metadata $msg).span }
  }
}

def ensure-parent-dir [path: string] {
  let parent = ($path | path dirname)
  if not (dir-exists $parent) {
    log info $"creating directory: ($parent)"
    mkdir $parent
  }
}

def has-cmd [cmd: string]: nothing -> bool {
  (which $cmd | is-not-empty)
}

def dir-exists [path: string]: nothing -> bool {
  if not ($path | path exists) { return false }
  ($path | path type) == "dir"
}

def is-fedora []: nothing -> bool {
  if not ("/etc/redhat-release" | path exists) { return false }
  let content = (open /etc/redhat-release | str downcase)
  $content =~ "fedora"
}

def link [source: string, target: string]: nothing -> bool {
  let src = ($source | path expand)

  if not ($src | path exists) {
    log error $"Skipping: ($src) does not exist"
    return false
  }

  if not ($src | str starts-with $"($env.DOT_DIR)/") {
    log error $"Skipping: ($src) is outside ($env.DOT_DIR)"
    return false
  }

  let dir = ($target | path dirname)
  if not ($dir | path exists) {
    mkdir $dir
  }

  let is_symlink = (do -i { ^readlink $target } | is-not-empty)

  if ($target | path exists) and (($target | path type) == "dir") and not $is_symlink {
    log error $"Skipping: ($target) is a directory"
    return false
  }

  if $is_symlink {
    let resolved = do -i { ^readlink -f $target }
    if ($resolved | is-not-empty) and ($resolved | str trim) == $src {
      log info $"Skipping: ($target) already links to ($src)"
      return true
    }
  }

  if ($target | path exists) or $is_symlink {
    log warning $"Trashing existing ($target), restore with 'trash-restore'"
    do -i { ^trash $target }
  }

  log info $"Linking ($src) -> ($target)"
  ^ln -s $src $target
  true
}

def dotify-path [p: string]: nothing -> string {
  $p | path split | each {|seg|
    if ($seg | str starts-with "dot-") {
      $".($seg | str substring 4..)"
    } else {
      $seg
    }
  } | path join
}

def link-all [source: string, target: string] {
  let root = ($source | path expand)

  for f in (glob $"($root)/**/*" --no-dir) {
    let src = ($f | path expand)
    let rel = ($src | path relative-to $root)
    let dst = ($target | path join (dotify-path $rel))
    link $src $dst
  }
}

def "main stow config" [package: string] {
  link-all ($env.DOT_DIR | path join $package) ($env.HOME | path join ".config" $package)
}

def "main stow" [package: string] {
  main stow config $package
}

def "main stow home" [package: string] {
  link-all ($env.DOT_DIR | path join $package) $env.HOME
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

def si [packages: list<string>] {
  log info "Installing packages"
  do -i { ^sudo dnf install -y ...$packages }
}

def touch-files [dir: string, files: list<string>] {
  do -i { mkdir $dir }

  for f in $files {
    let file_path = ($dir | path join $f)
    if not ($file_path | path exists) {
      log info $"creating file ($file_path)"
      touch $file_path
    }
  }
}

def set-fish-as-default-shell [] {
  if not (has-cmd fish) { die "fish not found. Quitting." }

  let fish_path = (which fish | first | get path)
  let current_shell = (
    ^getent passwd $env.USER
    | parse "{name}:{password}:{uid}:{gid}:{gecos}:{home}:{shell}"
    | get shell.0
    | str trim
  )

  if $current_shell == $fish_path {
    log info "fish is already the default shell."
    return
  }

  let etc_shells = "/etc/shells"
  let in_shells = if ($etc_shells | path exists) {
    open $etc_shells | lines | any {|l| $l == $fish_path }
  } else {
    false
  }

  if $in_shells {
    log info $"($fish_path) is already in /etc/shells."
  } else {
    log warning $"Adding ($fish_path) to /etc/shells."
    echo $fish_path | ^sudo tee -a $etc_shells
    if $env.LAST_EXIT_CODE != 0 {
      log error $"Failed to add ($fish_path) to /etc/shells."
      return
    }
  }

  ^chsh -s $fish_path
  if $env.LAST_EXIT_CODE == 0 {
    log info $"Default shell set to fish \(($fish_path)\). Re-login to apply."
  } else {
    log error $"Failed to set fish as default shell. Try running 'chsh -s ($fish_path)' manually."
  }
}

def "main fish" [] {
  si ["fish"]
  set-fish-as-default-shell
  main stow fish
}

def "main shell" [] {
  si [
    "bat"
    "difftastic"
    "duf"
    "fd"
    "gcc"
    "gdu"
    "gh"
    "git"
    "htop"
    "jq"
    "less"
    "libatomic"
    "make"
    "pipx"
    "plocate"
    "rclone"
    "ripgrep"
    "rsync"
    "shellcheck"
    "shfmt"
    "tar"
    "tealdeer"
    "tmux"
    "trash-cli"
    "ugrep"
    "unzip"
    "yq"
    "zstd"
  ]

  do -i { tldr --update }
  do -i { sudo updatedb }

  main fish
}

def --env bootstrap [] {
  path add $env.DOT_DIR
  path add "/home/linuxbrew/.linuxbrew/bin"

  for p in [
    "bin"
    ".local/bin"
  ] {
    path add ($env.HOME | path join $p)
  }
}

def "main brew" [] {
  if (has-cmd brew) { return }
  ^sudo -v
  log info "Installing brew"
  http get "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" | bash
  path add "/home/linuxbrew/.linuxbrew/bin"

  ^brew tap ublue-os/tap
  ^brew install topgrade
}

def "main rust" [] {
  if (has-cmd rustup) { return }
  ^curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}

def "main uv" [] {
  if (has-cmd uv) { return }
  ^curl -LsSf https://astral.sh/uv/install.sh | sh
}

def "main vp" [] {
  if (has-cmd vp) { return }
  curl -fsSL https://vite.plus | bash
  ~/.vite-plus/bin/vp install latest
}

def "main dev" [] {
  main rust
  main uv
  main vp
}

def "main fonts" [] {
  if (has-cmd brew) {
    brew install --cask font-jetbrains-mono-nerd-font font-monaspace-nerd-font
  }

  if (is-atomic) { return }
  si [
    "cascadia-mono-nf-fonts"
    "cascadia-code-nf-fonts"
    "adwaita-sans-fonts"
    "rsms-inter-vf-fonts"
    "material-symbols-fonts"
  ]
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

def "main docker" [] {
  if not (has-cmd docker) {
    si ["docker" "docker-compose"]
    sudo systemctl enable --now docker.socket
  }
  sudo usermod -aG docker $env.USER
}

def "main wallpapers" [] {
  let base = $"$($env.HOME)/.local/share/backgrounds"
  let dir = $"($base)/ml4w"
  if (dir-exists $dir) {
    log info "ML4W wallpapers already installed, skipping"
    return
  }

  log info "Installing ML4W wallpapers"
  mkdir $base
  git clone --depth=1 https://github.com/mylinuxforwork/wallpaper.git $dir
  log info "ML4W wallpapers installed successfully"
}

def "main kitty" [] {
  if (is-atomic) {
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
  } else {
    si ["kitty"]
  }

  touch-files ~/.config/kitty ["local.conf", "dank-theme.conf", "dank-tabs.conf"]
  main stow "kitty"
}

def "main wm" [] {
  main fonts
  main kitty

  log info "Installing window manager packages"
  si [
    "adw-gtk3-theme"
    "alacritty"
    "brightnessctl"
    "cups-pk-helper"
    "ddcutil"
    "default-fonts"
    "default-fonts-core-emoji"
    "distribution-gpg-keys"
    "fastfetch"
    "fuse"
    "fuse-common"
    "fuzzel"
    "fwupd"
    "gcr"
    "gcr"
    "gnome-keyring"
    "gnome-keyring-pam"
    "google-noto-color-emoji-fonts"
    "google-noto-emoji-fonts"
    "grim"
    "gvfs"
    "gvfs-fuse"
    "gvfs-smb"
    "imv"
    "kf6-kimageformats"
    "libsecret"
    "lm_sensors"
    "lshw"
    "mate-polkit"
    "mpv"
    "nautilus"
    "ncurses"
    "pipewire"
    "pipewire-gstreamer"
    "pipewire-pulse"
    "pipewire-pulseaudio"
    "playerctl"
    "qt5ct"
    "qt6-qtimageformats"
    "qt6-qtmultimedia"
    "qt6ct"
    "slurp"
    "tuned"
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

  main stow "xdg-desktop-portal"
}

def "main greetd keyring fix" [] {
  let pam_file = "/etc/pam.d/greetd"

  if not ($pam_file | path exists) {
    error+ "PAM file not found: ($pam_file)"
    return
  }

  let lines = (open $pam_file | lines)

  let new_lines = ($lines | each {|l|
    if ($l | str contains "pam_gnome_keyring.so") {
      $l | str replace --regex '^\s*-' ''
    } else {
      $l
    }
  })

  if $lines == $new_lines {
    print "No changes needed."
    exit
  }

  let backup = $"($pam_file).bak"

  cp $pam_file $backup

  $new_lines
  | str join (char nl)
  | save --force $pam_file

  print $"Updated ($pam_file)"
  print $"Backup written to ($backup)"
}

def "main greetd" [] {
  if not (has-cmd dms) {
    log error "dms is not installed. Cannot setup greetd."
    return
  }

  log info "Installing greeter"
  si ["dms-greeter"]
  dms greeter enable
  log info "After logging in with greetd, run `dms greeter sync` to apply changes."

  main greetd keyring fix
}

def "main niri install" [] {
  main wm

  if (has-cmd dms) and (has-cmd niri) {
    log info "niri and dms are already installed"
    return
  }

  log info "Installing niri and dms"
  ^sudo dnf copr enable -y avengemedia/dms
  ^sudo dnf copr enable -y yalter/niri
  si ["niri" "dms" "cliphist"]
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

def "fpi" [pkgs: list<string>] {
  for pkg in $pkgs {
    log info $"Installing ($pkg)"
    do -i { ^flatpak --user install -y flathub $pkg }
  }
}

def "main flathub" [] {
  log info "Adding flathub remote"
  ^flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo --user
}

def "main flatpak" [] {
  if not (has-cmd flatpak) { si ["flatpak"] }
  main flathub
  let flatpaks = ["com.github.tchx84.Flatseal"]
  fpi $flatpaks
}

def "main apps" [] {
  main flatpak

  let flatpaks = [
    "app.zen_browser.zen"
    "md.obsidian.Obsidian"
    "org.gnome.Papers"
  ]

  fpi $flatpaks
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
    "libosinfo"
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
  si ["podman" "distrobox"]
  main virt install
  main virt config
}

def "main incus" [] {
  log info "Installing incus"
  si ["incus" "incus-tools"]

  log info "Adding user to incus groups"
  do -i {
    sudo usermod -aG incus $env.USER
    sudo usermod -aG incus-admin $env.USER
  }

  log info "Enabling incus socket"
  do -i { sudo systemctl enable --now incus.socket }

  log info "Configuring firewalld for incus"
  do -i {
    sudo firewall-cmd --zone=trusted --change-interface=incusbr0 --permanent
    sudo firewall-cmd --reload
  }

  log info "Initializing incus admin"
  do -i { sg incus-admin -- incus admin init --minimal }

  log info "Incus configured. Reboot your system and use incus.nu script."
}

def "main desktop" [] {
  main virt
  main flatpak
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

def "main home-manager" [] {
  log info "Installing home-manager"
  if not (has-cmd nix) {
    log error "Nix is not installed. Please install it first."
    return
  }

  nix run home-manager -- switch --flake "$($env.HOME)/.fedora-config/scripts/home-manager#($env.USER)" --impure
}

let ALL_COMMANDS = {
  "shell": {
    desc: "Install shell tools and set Fish as default shell"
    run: {|| main shell }
  }
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
  flatpak: {
    desc: "Install and configure flatpak"
    run: {|| main flatpak }
  }
  apps: {
    desc: "Install and configure flatpak applications(zen browser, obsidian)"
    run: {|| main apps }
  }
  brew: {
    desc: "Install Homebrew"
    run: {|| main brew }
  }
  zed: {
    desc: "Install and configure Zed editor"
    run: {|| main zed }
  }
  "rust": {
    desc: "Install and configure Rust toolchain"
    run: {|| main rust }
  }
  "uv": {
    desc: "Install and configure uv(Python)"
    run: {|| main uv }
  }
  "vp": {
    desc: "Install and configure Vite Plus(Node)"
    run: {|| main vp }
  }
  "home-manager": {
    desc: "Install and configure Home Manager"
    run: {|| main home-manager }
  }
  "kitty": {
    desc: "Install and configure Kitty terminal"
    run: {|| main kitty }
  }
}

let ATOMIC_COMMANDS = ($ALL_COMMANDS |
  select  "kitty" "shell" "flatpak" "apps" "zed" "rust" "uv" "vp")

let COMMANDS = if (is-atomic) {
  $ATOMIC_COMMANDS
} else {
  $ALL_COMMANDS
}

def run-command [cmd: string] {
  let key = ($cmd | str trim)
  if not ($key in $COMMANDS) {
    log warning $"Unknown command: ($key)"
    return
  }
  do ($COMMANDS | get $key).run
}

def multi-select-installer [] {
  $COMMANDS | columns
  | input list --multi
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
  print "  greetd           Configure greetd greeter(disables SDDM/GDM)"
  print "  stow-config <pkg> Symlink a config package into ~/.config/<pkg>"
  print "  stow-home <pkg>  Symlink a package into ~ (use 'dot-' prefix for dotfiles)"

  $COMMANDS | transpose name value | each {|row| print $"  ($row.name | fill -w 16) ($row.value.desc)" }

  print ""
  print "  virt config      Configure libvirt"
  print "  kitty            Install and Configure Kitty terminal"
  print "  wallpapers       Wallpapers from Ml4w github repository"

  print ""
  print "  dev              Install development tools"
  print "  rust             Install Rust toolchain"
  print "  uv               Install UV toolchain"
  print "  nix              Install Nix package manager"
  print "  vp               Install Vite Plus"
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

def prerequisites [] {
  if not (check-commands "trash" "git" "nix") {
    die "Required commands not available. Quitting."
  }

  if not (is-fedora) {
    die "Only Fedora supported. Quitting."
  }
}

def "main default" [] {
  prerequisites
  bootstrap
  main update
}

def main [] {
  main default
  multi-select-installer
}
