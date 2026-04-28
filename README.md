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

After the repo is available locally(bootstrap step), run the setup.nu script directly:

```sh
setup.nu
```

You could choose to install homebrew. In such a case, you could install packages using brew.

```bash
brew install font-jetbrains-mono-nerd-font
brew install --cask antigravity-linux
```

Install desktop applications with `flatpak` from [flatpak](https://flathub.org/en)).

```bash
flatpak install --user flathub com.google.Chrome
```
