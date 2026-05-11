#!/usr/bin/env nu

def fail [msg: string] {
  error make { msg: $msg }
}

def assert [cond: bool, msg: string] {
  if not $cond { fail $msg }
}

def assert-link [path: string, expected: string] {
  let target = (do -i { ^readlink $path } | str trim)
  assert ($target | is-not-empty) $"Expected symlink at ($path)"
  assert ($target == ($expected | path expand)) $"Unexpected link target for ($path): ($target)"
}

def main [] {
  let tmp = (^mktemp -d | str trim)
  let home = ($tmp | path join "home")
  let dot_dir = ($tmp | path join "repo")

  mkdir $home
  mkdir ($dot_dir | path join "git")
  mkdir ($dot_dir | path join "nvim/lua")
  mkdir ($dot_dir | path join "homepkg")

  "[user]" | save -f ($dot_dir | path join "git/dot-gitconfig")
  "return {}" | save -f ($dot_dir | path join "nvim/lua/init.lua")
  "set -gx DEMO 1" | save -f ($dot_dir | path join "homepkg/dot-demo")

  with-env { HOME: $home, DOT_DIR: $dot_dir } {
    stow.nu config git
    stow.nu config nvim
    stow.nu home homepkg
  }

  assert-link ($home | path join ".config/git/.gitconfig") ($dot_dir | path join "git/dot-gitconfig")
  assert-link ($home | path join ".config/nvim/lua/init.lua") ($dot_dir | path join "nvim/lua/init.lua")
  assert-link ($home | path join ".demo") ($dot_dir | path join "homepkg/dot-demo")

  print "stow smoke test passed"
}
