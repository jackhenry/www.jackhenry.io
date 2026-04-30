{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = {self, ...} @ inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      perSystem = {
        pkgs,
        lib,
        config,
        system,
        ...
      }: {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            just
            pandoc
            yq
            static-web-server
            watchexec
            vscode-css-languageserver
            superhtml
            typescript-language-server
          ];

          shellHook = ''
            echo "Run 'just' to see available commands"
          '';
        };
        packages = {
          site = pkgs.callPackage ./pkgs/mkSite {
            inherit lib;
            postsSrc = ./posts;
            pagesSrc = ./pages;
            baseUrl = "https://www.jackhenry.io";
          };
          site-local = pkgs.writeShellScript "serve-local" ''
            echo "Serving site locally on port 8080"
            ${pkgs.static-web-server}/bin/static-web-server --port 8080 --root ${config.packages.site}
          '';
          default = config.packages.site;
        };

        apps = {
          local = {
            type = "app";
            program = "${config.packages.site-local}";
          };
          default = config.apps.local;
        };
      };
    };
}
