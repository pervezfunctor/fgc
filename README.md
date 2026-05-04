# Fedora Config

## Bootstrap

First install all updates and reboot your computer.

```bash
sudo dnf upgrade --offline
```

Run the following bootstrap script

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pervezfunctor/fedora-config/main/scripts/fedora-setup)"
```

This script clones this repo to `~/.fedora-config`, installs nix and installs fish as your default shell.

Reboot your computer and open terminal. You should be in fish shell.

```sh
echo $shell
```

If fish shell is not the default, use the following command.

```sh
chsh -s $(which fish) $user
```

## Setup commands

Use the following interactive script install additional software(docker, vscode, libvirt, niri etc).

```sh
~/.fedora-config/scripts/setup.nu
```

Install desktop applications with [flatpak](https://flathub.org/en)).

```sh
setup.nu flatpak
flatpak install --user flathub com.google.Chrome
```

Shell tools not available in official fedora repositories, should be available with `nix`.

```sh
setup.nu home-manager
```

Now add your packages to `home.pacakges` in `~/.fedora-config/home-manager/home.nix`. Then run

```sh
hms
```

## Niri setup

Currently this repository uses latest versions of niri and dms using copr packages(by the creators of niri and dms). Installation might break occasionally. So use this with caution.

```sh
setup.nu niri
```

It's extremely important that you open dms settings(Super+comma) from the top bar and at least change

- Power settings(monitor and system sleep)
- Wallpaper
- Theme
- Default fonts
- Time and weather
- Display Configuration(monitor resolutions)

Most of your desktop configuration should be there and this repository does not set them.

All your keybindings will be in ~/.config/niri/config/binds.kdl. You could also list all keybindings with "Super+Shift+/" keybinding.

Some important keybindings

- Open Terminal - Super+Return
- Application Launcher - Super+D
- Pick Predefined Size - Super+R (This is super important)
- Center Window - Super+C (Super important)
- Overview - Super+O (Super important)
- Close Window - Super+Q
- Switch Focus - Super+<Arrow Key>
- Move Window - Super+Shift+<Arrow Key>
- Switch Workspace - Super+<Number>
- Move Window to Workspace - Super+Shift+<number>
