{
  #inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
  #inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  #inputs.nixpkgs.url = "github:wineee/nixpkgs/deepin-23";
  inputs.nixpkgs.url = "github:a-n-n-a-l-e-e/nixpkgs/deliantra-server";

  outputs = {
    self,
    nixpkgs,
    }@inputs:
  let
    forSystems = systems: f: nixpkgs.lib.genAttrs systems (system: f rec {
      inherit system;
      inherit (nixpkgs.legacyPackages.${system}) pkgs lib;
    });
    forAllSystems = forSystems [
      "x86_64-linux"
      #"aarch64-linux"
      #"riscv64-linux"
    ];
  in {
    inherit inputs;

    packages = forAllSystems ({ pkgs, ...}: {
      deliantra-vm = self.nixosConfigurations.deliantra-vm.config.system.build.vm;
      deepin-vm = self.nixosConfigurations.deepin-vm.config.system.build.vm;
      nixos-rebuild-nom = with pkgs; writeScriptBin "nixos-rebuild" ''
        exec ${lib.getExe nixos-rebuild} "$@" |& ${lib.getExe nix-output-monitor}
      '';
    });

    nixosConfigurations = let
      mkNixos = extraModules: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ config, pkgs, lib, ... }: {
            system.stateVersion = lib.trivial.release;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            console.keyMap          = "no";
            services.xserver.layout = "no";
            i18n.defaultLocale      = "en_US.utf8";
            time.timeZone           = "Europe/Oslo";
            fonts.packages = with pkgs; [ noto-fonts noto-fonts-cjk noto-fonts-emoji ];

            users.users.test = {
              name = "Testy McTesticle";
              uid = 1000;
              extraGroups = [ "wheel" "networkmanager" ];
              isNormalUser = true;
              password = "test";
            };

            imports = [ "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];
            virtualisation = {
              qemu.options = [ "-device intel-hda -device hda-duplex" ];
              cores = 4;
              memorySize = 8 * 1024;
              diskSize = 16 * 1024;
              #resolution = { x = 1280; y = 800; };
              resolution = { x = 1920; y = 1080; };
            };

            environment.systemPackages = with pkgs; [
              pkgs.cage
              pkgs.firefox
            ];
          })
        ] ++ extraModules;
      };
    in {
      deliantra-vm = mkNixos [({ config, pkgs, lib, ... }: {
        services.deliantra-server.enable = true;
      })];
      deepin-vm = mkNixos [({ config, pkgs, lib, ... }: {
        services.xserver = {
          enable = true;
          displayManager = {
            lightdm.enable = true;
            autoLogin.enable = false;
            autoLogin.user = "test";
          };
          desktopManager.deepin.enable = true;
          #desktopManager.deepin.full = false;
        };
        environment.systemPackages = with pkgs; [

          deepin.deepin-album
          deepin.deepin-calculator
          deepin.deepin-camera
          deepin.deepin-compressor
          deepin.deepin-desktop-schemas
          deepin.deepin-desktop-theme
          deepin.deepin-draw
          deepin.deepin-editor
          deepin.deepin-image-viewer
          deepin.deepin-kwin
          deepin.deepin-movie-reborn
          deepin.deepin-music
          deepin.deepin-ocr-plugin-manager
          deepin.deepin-pdfium
          deepin.deepin-picker
          deepin.deepin-pw-check
          deepin.deepin-reader
          deepin.deepin-screen-recorder
          deepin.deepin-screensaver
          deepin.deepin-service-manager
          deepin.deepin-shortcut-viewer
          deepin.deepin-system-monitor
          deepin.deepin-terminal
          deepin.deepin-turbo
          deepin.deepin-voice-note
          deepin.deepin-wallpapers
          deepin.image-editor
        ];
      })];
    };

    devShells = forAllSystems ({ pkgs, system, ... }: let
      mkShell = packages: pkgs.mkShellNoCC { inherit packages; };
    in {

      default = mkShell [
        self.packages.${system}.nixos-rebuild-nom
        pkgs.nix-output-monitor
        pkgs.remote-exec
        pkgs.rsync
      ];

    });

  };
}
