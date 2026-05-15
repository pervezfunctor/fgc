#!/usr/bin/env nu

use std/log
use std/util "path add"

export def "log+" [msg: string] {
  let colored = $"(ansi green)📝 ($msg)(ansi reset)"
  log info $colored
  print $colored
}

export def "warn+" [msg: string] {
  let colored = $"(ansi yellow) ⚠️ ($msg)(ansi reset)"
  log warning $colored
  print $colored
}

export def "error+" [msg: string] {
  let colored = $"(ansi red)🚨 ($msg)(ansi reset)"
  log error $colored
  print $colored
}

export def "success+" [msg: string] {
  let colored = $"(ansi green)✅ ($msg)(ansi reset)"
  log info $colored
  print $colored
}

export def "failure+" [msg: string] {
  let colored = $"(ansi red)❌ ($msg)(ansi reset)"
  log error $colored
  print $colored
}

export-env {
  if "DOT_DIR" not-in ($env | columns) {
    $env.DOT_DIR = ($env.HOME | path join ".fedora-config")
  }
}

export def is-atomic []: nothing -> bool {
  has-cmd rpm-ostree
}

export def is-ublue []: nothing -> bool {
  (is-atomic) and (has-cmd ujust)
}

export def die [msg: string] {
  log critical $msg

  error make {
    msg: $msg
    label: { text: "fatal error", span: (metadata $msg).span }
  }
}

export def dir-exists [path: string]: nothing -> bool {
  if not ($path | path exists) { return false }
  ($path | path type) == "dir"
}

export def has-cmd [cmd: string]: nothing -> bool {
  (which $cmd | is-not-empty)
}

export def is-fedora []: nothing -> bool {
  if not (has-cmd dnf) {
    return false
  }

  if not ("/etc/redhat-release" | path exists) { return false }
  let content = (open /etc/redhat-release | str downcase)
  $content =~ "fedora"
}

export def group-add [group: string] {
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
  let dir = ($dir | path expand)
  do -i { mkdir $dir }

  for f in $files {
    let file_path = ($dir | path join $f)
    if not ($file_path | path exists) {
      log info $"creating file ($file_path)"
      touch $file_path
    }
  }
}

export def --env bootstrap [] {
  path add $env.DOT_DIR
  path add "/home/linuxbrew/.linuxbrew/bin"

  for p in [
    "bin"
    ".pixi/bin"
    ".local/bin"
  ] {
    path add ($env.HOME | path join $p)
  }
}

export def update [] {
  log info "Updating packages"
  ^sudo dnf update -y
}

export def check-commands [...cmds: string]: nothing -> bool {
  mut result = true
  for cmd in $cmds {
    if not (has-cmd $cmd) {
      warn+ $"($cmd) not available"
      result := false
    }
  }
  $result
}

export def prerequisites [] {
  if not (check-commands "trash" "git" "pixi") {
    die "Required commands not available. Quitting."
  }

  if not (is-fedora) {
    die "Only Fedora supported. Quitting."
  }
}

export def brew-install [] {
  if (has-cmd brew) {
    log info "brew is already installed"
    return
  }
  ^sudo -v
  log info "Installing brew"
  http get "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" | bash
  path add "/home/linuxbrew/.linuxbrew/bin"

  ^brew tap ublue-os/tap
  ^brew install topgrade
}


export def get-pubkey [ssh_key: string] {
  if ($ssh_key | is-empty) {
    let pubkey_path = $"($env.HOME)/.ssh/id_ed25519.pub"
    if not ($pubkey_path | path exists) {
      ^ssh-keygen -t ed25519 -f $"($env.HOME)/.ssh/id_ed25519" -q -N ""
    }
    open $pubkey_path | str trim
  } else {
    $ssh_key
  }
}

export def "fonts" [] {
  if (is-atomic) { return }

  si [
    "cascadia-mono-nf-fonts"
    "cascadia-code-nf-fonts"
    "adwaita-sans-fonts"
    "rsms-inter-vf-fonts"
  ]
}

export def stow [...args: string] {
  for arg in $args {
    nu $"($env.DOT_DIR)/scripts/stow.nu" $arg
  }
}

export def multi-task [items: list<record<description: string, handler: closure>>] {
  let selected = ($items | input list --multi --display description "Select tasks to execute:")

  if ($selected | is-empty) {
    log info "No tasks selected."
    return
  }

  for item in $selected {
    log info $"Executing: ($item.description)"
    try {
      do $item.handler
    } catch {|err|
      log error $"($item.description) failed."
      $err | print
    }
  }
}
