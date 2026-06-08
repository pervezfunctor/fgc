# Fedora Config

## Bootstrap

First, update your system and reboot your computer. This will save a lot of time, when executing the following scripts.

```sh
sudo dnf update -y --refresh # fedora workstation
ujust update # bluefin
sudo rpm-ostree upgrade # silverblue
```

Then run the following bootstrap script

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/pervezfunctor/fgc/main/scripts/setup)"
```

This script clones this repo to `~/.fgc`, and add a single line to your ~/.bashrc to put all scripts on PATH.

## Shell

Restart your terminal and execute the following script. This install shell tools and sets up fish as default.

```sh
fgc shell
```

Reboot your computer and open terminal. You should be in fish shell.

```sh
echo $SHELL
```

If fish shell is not the default, use the following command.

```sh
chsh -s $(which fish)
```

## Development Tools

Install node(vite+), Rust(rustup), Python(uv).

```sh
fgc dev
```

Install and setup your preferred editor

```sh
fgc zed
```

```sh
fgc vscode
```

## Virtual Machines

incus supports simple cloud-init based virtual machines that are great for development.

Install and setup incus with

```sh
vm install
```

Reboot your computer. Then execute the following.

```sh
vm install post
```

Create a Debian VM with

```sh
vm debian         # one of debian, fedora, ubuntu, tumbleweed and arch
```

Wait for a few minutes(for cloud-init to finish), list all VMs, confirm they have IPv4 address assigned and SSH into the one you just created.

```sh
vm list
vm ssh <name> # or ssh "$USER"@<ip-address>
```

For additional commands

```sh
vm help
```

If you prefer `virt-manager` for installing desktop linux distributions, install with dnf and restart your computer.

```sh
sudo dnf install -y virt-manager
```

## Gnome setup

To setup gnome almost like niri, and use scrolling layout(paperwm), use the following script

```sh
setup gnome
```

Some important keybindings

- Open Terminal - Super+Return
- Pick Predefined Size - Super+R (This is super important)
- Center Window - Super+C (Super important)
- Close Window - Super+Q
- Switch Focus - Super+<Arrow Key>
- Move Window - Super+Shift+<Arrow Key>
- Switch Workspace - Super+Page_Up/Page_Down
- Move Window to Workspace - Super+Shift+Page_Up/Page_Down

## Bluefin

No need to use scripts from this repository. Use the following instead.

First switch to devmode

```sh
ujust devmode
```

Restart computer and setup dev groups.

```sh
ujust dx-group
```

Restart your computer again. You should have `incus`, `libvirt` and `vscode` installed.

You could setup your shell with

```sh
ujust bluefin-cli
```
