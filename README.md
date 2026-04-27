# Fedora Niri Config

## Bootstrap

First install all updates.

```bash
sudo dnf update -y
```

Run the bootstrap script:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pervezfunctor/fedora-niri-config/main/setup)"
```

The bootstrap script clones the repo to `~/.fedora-niri-config`, installs pixi and configures fish as default shell.

## Setup commands

After the repo is available locally, run the setup.nu script directly:

```sh
setup.nu
```

Available commands include:

```sh
setup.nu help
setup.nu niri
setup.nu flatpaks
setup.nu virt
setup.nu docker
```

You could also install `homebrew` for linux.

```bash
setup.nu brew
```

And install packages using brew.

```bash
brew install --cask antigravity-linux
brew install opencode
```
