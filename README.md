# Fedora Config

## Bootstrap

First install all updates.

```bash
sudo dnf update -y
```

Then, run the bootstrap script:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pervezfunctor/fedora-config/main/scripts/fedora-setup)"
```

The bootstrap script clones the repo to `~/.fedora-config`, installs pixi and configures fish as default shell.

## Setup commands

After the repo is available locally, run the setup.nu script directly:

```sh
setup.nu
```

Available commands include:

```sh
setup.nu help
setup.nu vscode
setup.nu docker
setup.nu virt
setup.nu flatpaks
setup.nu niri
```

You could also install `homebrew` for linux.

```bash
setup.nu brew
```

And install packages using brew.

```bash
brew install font-jetbrains-mono-nerd-font
brew install --cask antigravity-linux
```

Install desktop application with `flatpak` from [flatpak](https://flathub.org/en))

```bash
flatpak install --user flathub com.google.Chrome
```
