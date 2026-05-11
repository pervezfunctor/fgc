#!/usr/bin/env nu

use std/log
use ./lib.nu *

def "main dev" [...args] {
    nu ($env.FILE_PWD | path join "dev.nu") ...$args
}

def "main ui" [...args] {
    nu ($env.FILE_PWD | path join "ui.nu") ...$args
}

def "main vscode" [...args] {
    nu ($env.FILE_PWD | path join "vscode.nu") ...$args
}

def "main libvirt" [...args] {
    nu ($env.FILE_PWD | path join "libvirt.nu") ...$args
}

def "main niri" [] {
    main ui niri
}

def "main apps" [] {
    main ui apps
}

def "main brew" [] {
    brew-install
}

def "main zed" [] {
    main dev zed
}

def "main help" [] {
    print $"Usage: setup.nu <command> [args...]

Commands:
  niri              Install and configure niri
  apps              Install apps like zen browser, obsidian, papers
  dev               Development tools \(rust, uv, vp\)
  zed               Install and configure Zed editor
  vscode            Install and configure vscode
  libvirt           Install and configure libvirt/virt-manager
  brew              Install Homebrew

  help               Show this help message
"
}

def main [...args] {
    if ($args | is-empty) {
        main help
    } else {
        log error $"Unknown command: ($args | first)"
        main help
    }
}
