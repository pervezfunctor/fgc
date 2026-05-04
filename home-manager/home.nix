{ pkgs, vars, ... }:
{

  nixpkgs.config.allowUnfree = true;
  fonts.fontconfig.enable = true;

  home = {
    username = vars.username;
    homeDirectory = vars.homeDirectory;
    stateVersion = "25.11";

    packages = with pkgs; [
      devbox
      devenv
      nil
      nixd
      nixfmt
      carapace
      dysk
      bottom
      nushell
      starship
      television
      xh
      bibata-cursors
      nerd-fonts.monaspace
      nerd-fonts.jetbrains-mono

      eza
      direnv
      fzf
      zoxide
    ];
  };

  programs = {
    home-manager.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };

    nushell = {
      enable = true;
      plugins = [ pkgs.nushellPlugins.formats ];
      settings = {
        show_banner = false;
      };
    };
  };

  #   fish = {
  #     enable = true;
  #   };

  #   eza = {
  #     enable = true;
  #     enableFishIntegration = true;
  #     enableNushellIntegration = true;
  #   };

  #   starship = {
  #     enable = true;
  #     enableFishIntegration = true;
  #     enableZshIntegration = true;
  #     enableNushellIntegration = true;
  #   };

  #   carapace = {
  #     enable = true;
  #     enableFishIntegration = true;
  #     enableNushellIntegration = true;
  #   };

  #   fzf = {
  #     enable = true;
  #     enableFishIntegration = true;
  #   };

  #   zoxide = {
  #     enable = true;
  #     enableFishIntegration = true;
  #     enableNushellIntegration = true;
  #   };

  # };

  nix = {
    package = pkgs.nix;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      max-jobs = "auto";
      cores = 2;

      substituters = [
        "https://cache.nixos.org/"
      ];

      warn-dirty = false;
    };
  };
}
