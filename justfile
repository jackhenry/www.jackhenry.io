build:
    nix build

clean:
    rm -rf ./result

dev:
    watchexec -r -e nix,md,html,js,css -- nix run
