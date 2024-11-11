{
  #inputs.nixpkgs.url = "github:nixos/nixpkgs/master";
  #inputs.nixpkgs.url = "github:nixos/nixpkgs/staging";
  #inputs.nixpkgs.url = "github:nixos/nixpkgs/staging-next";
  #inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  #inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  #inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/refs/pull/355279/merge";

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

    packages = forAllSystems ({ pkgs, lib, ...}: {
      nixos-rebuild-nom = with pkgs; writeScriptBin "nixos-rebuild" ''
        exec ${lib.getExe nixos-rebuild} "$@" |& ${lib.getExe nix-output-monitor}
      '';
    } // (lib.flip lib.mapAttrs' self.nixosConfigurations (name: value:
      lib.nameValuePair name value.config.system.build.vm
    )));

    nixosConfigurations = let
      mkNixos = extraModules: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ config, pkgs, lib, ... }: {
            system.stateVersion = lib.trivial.release;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            console.keyMap = "no";
            services.xserver.xkb.layout = "no";
            i18n.defaultLocale = "en_US.utf8";
            time.timeZone = "Europe/Oslo";
            fonts.packages = with pkgs; [ noto-fonts noto-fonts-cjk-sans noto-fonts-emoji ];
            networking.firewall.allowedTCPPorts = [ 8080 ];

            users.users.root.password = "hunter2";
            users.users.test = {
              name = "Testy McTesticle";
              uid = 1000;
              extraGroups = [ "wheel" "networkmanager" ];
              isNormalUser = true;
              password = "test";
            };

            imports = [ "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];
            virtualisation = {
              qemu.options = [ "-device intel-hda -device hda-duplex -vga virtio" ];
              cores = 4;
              memorySize = 8 * 1024;
              diskSize = 16 * 1024;
              #resolution = { x = 1280; y = 800; };
              resolution = { x = 1920; y = 1080; };
            };

            environment.systemPackages = with pkgs; [
              pkgs.tmux
              pkgs.cage
              pkgs.firefox
              pkgs.htop
              pkgs.fd
              pkgs.ripgrep
              pkgs.bat
            ];
          })
        ] ++ extraModules;
      };
    in {
      invidious-vm = mkNixos [({ config, pkgs, lib, ... }: {
        services.invidious = {
          enable = true;
          domain = "invidious.example.com";
          address = "0.0.0.0";
          port = 8080;
          settings = {
            external_port = 8080;
            https_only = false;
            statistics_enabled = false; # api endpoint required for public instances
            registration_enabled = true;
            login_enabled = true;
            banner = "Testy McTesticles";
            default_user_preferences = {
              feed_menu = ["Trending" "Subscriptions" "Playlists"];
              default_home = "Trending";
            };
          };
        };
      })];
      resilio-vm = mkNixos [({ config, pkgs, lib, ... }: {
        nixpkgs.config.allowUnfreePredicate = x: true;
        services.resilio.enable = true;
      })];
      goatcounter-vm = mkNixos [({ config, pkgs, lib, ... }: {
        services.goatcounter.enable = true;
        services.goatcounter.address = "0.0.0.0";
        services.goatcounter.port = 8080;
        services.goatcounter.proxy = true;
      })];
      terraria-vm = mkNixos [({ config, pkgs, lib, ... }: {
        nixpkgs.config.allowUnfreePredicate = x: true;
        services.terraria.enable = true;
      })];
      ttyd-login-vm = mkNixos [({ config, pkgs, lib, ... }: {
        services.ttyd.enable = true;
        services.ttyd.interface = "0.0.0.0";
        services.ttyd.port = 8080;
        services.ttyd.writeable = true;
      })];
      ttyd-htop-vm = mkNixos [({ config, pkgs, lib, ... }: {
        services.ttyd.enable = true;
        services.ttyd.interface = "0.0.0.0";
        services.ttyd.port = 8080;
        services.ttyd.writeable = false;
        services.ttyd.entrypoint = [ (lib.getExe pkgs.htop) ];
      })];
      pyload-vm = mkNixos [({
        services.pyload.enable = true;
        services.pyload.listenAddress = "0.0.0.0";
        services.pyload.port = 8080;
      })];
      firebird-vm = mkNixos [({
        services.firebird.enable = true; # check if it builds
      })];
      tigerbeetle-vm = mkNixos [({
        services.tigerbeetle.enable = true;
        services.tigerbeetle.addresses = [ "0.0.0.0:80" ];
      })];
      deliantra-vm = mkNixos [({ config, pkgs, lib, ... }: {
        services.deliantra-server.enable = true;
      })];
      auto-epp-vm = mkNixos [({ config, pkgs, lib, ... }: {
        services.auto-epp.enable = true;
      })];
      gnome-vm = mkNixos [({ config, pkgs, lib, ... }: {
        services.xserver = {
          enable = true;
          displayManager.autoLogin.enable = false;
          displayManager.autoLogin.user = "test";
          displayManager.gdm.enable = true;
          desktopManager.gnome.enable = true;
        };
        services.dbus.packages = with pkgs; [ gnome2.GConf ];
        imports = [
          # https://github.com/NixOS/nixpkgs/pull/264774
          /** /
          {
            qt.enable = true;
            #qt.waylandDecoration = "adwaita";
            environment.variables.QT_WAYLAND_DECORATION="adwaita";
            environment.systemPackages = with pkgs; [ qadwaitadecorations-qt6 qt6.qtsvg obs-studio shotcut ];
            environment.systemPackages = with pkgs; [ obs-studio shotcut ];
          }
          /**/
        ];
      })];
      deepin-vm = mkNixos [({ config, pkgs, lib, ... }: {
        services.xserver = {
          enable = true;
          displayManager.lightdm.enable = true;
          displayManager.autoLogin.enable = false;
          displayManager.autoLogin.user = "test";
          desktopManager.deepin.enable = true;
          #desktopManager.deepin.full = false;
        };
        # https://github.com/NixOS/nixpkgs/pull/257400
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
