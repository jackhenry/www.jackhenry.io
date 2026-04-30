---
key: 'rust-esp32-nix'
publish: true
author: 'Jack Henry'
title: 'Rust ESP32 Development on NixOS'
description: "Setting up a Rust-based ESP32 development environment in NixOS."
pubDate: 2025-10-15
tags:
  - rust
  - embedded
  - nix
  - nixos
  - esp32
---

> [!TIP]
> The `esp-rs/esp-hal` package is currently approaching `v1.0` release. `esp-generate` pins the package at `1.0.0-rc.0` in the `Cargo.toml`. The API will undergo changes before stable release. 

I've had a [ESP32-C6-DevKitC-1](https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32c6/esp32-c6-devkitc-1/user_guide.html) development board sitting in a drawer for a year. I originally purchased it because I wanted to work with RISC-V architecture. Since life has a penchant for eating up free-time, I never got around to actually using the board in any projects.

Alas, I've decided to finally dust off the microcontroller and write some software for it. Naturally, the first step in writing software is setting up your development environment. Unfortunately, development environments for embedded systems are typically complex. They're riddled with vendor/proprietary tools, documentation is lacking, and there's an inherent requirement for cross-compilation.

This article will outline the approach I took for setting up a Rust development environment for my ESP32 board.

## The Goal

The ultimate goal of a development environment is the facilitation of rapid software prototyping. Ideally, it shouldn't require various incantations to build and run your binary. I will expand upon this later, but the tool [probe-rs](https://probe.rs/) will be utilized in conjunction with `cargo` to accomplish this. 

Next, the development environment should be portable. Portable in the sense that I should be able to clone the repo to any NixOS system and immediately begin developing. This isn't too difficult in the Nix ecosystem. Typically, you would employ the use of a `flake.nix` that defines at least one shell in the `devShells` attribute.

Lastly, I want to avoid the requirement of having the development board directly attached to the development workstation. The board possesses a USB-C port that ties in with the ESP32 debug interface. If following Espressif's documentation, you would need to have the development board physically plugged into the development machine. This is cumbersome since I'd prefer not to carry the board around with me if I want to work at a café. Therefore, I'd like to keep the development board plugged into a stationary server. Then, on my development machine, I should be able to push new builds to the board over my VPN connection.

## The Server

Let's start with the server that will be connected directly to the development board.

As mentioned previously, `probe-rs` is a useful tool for setting up a Rust ESP32 development environment. It's primary function is to interface directly with the development board. Most importantly, this includes deploying build artifacts to the board by directly copying them to the necessary locations in memory. The tool is even available directly from `nixpkgs` which makes it even easier to use in a `devShell`.

Unfortunately, there's one caveat. By default, `probe-rs` isn't compiled with a necessary feature. Specifically, the `remote` feature. This feature allows `probe-rs` to run in a client/server configuration. The type of configuration amenable to my previously stated goals.

Therefore, it will be necessary to implement the use of an overlay that uses the `overrideAttrs` function to enable the `remote` feature for `probe-rs`. This can be done as such:

```nix
(final: prev: {
  probe-rs-with-remote = prev.probe-rs.overrideAttrs (old: {
    cargoBuildFlags = ["--features=remote"]; # Needed for probe-rs client/server functionality
  });
})
```
`probe-rs` with the `remote` feature needs to be available on both the remote server and the development environment. Ultimately, I ended up installing the overriden `probe-rs` as a system package on the server.

Furthermore, you might want to adjust `udev` rules to allow for non-root users to utilize `probe-rs`. Something like this:

```nix
services.udev.extraRules = ''
  # Allow access to Espressif USB JTAG / Serial devices
  SUBSYSTEM=="usb", ATTR{idVendor}=="303a", MODE="0666"
'';
```

After `probe-rs` has the necessary override, a `.probe-rs.toml` config file will be needed. The contents of the config file are straightforward and mostly self-explanatory:

```toml
[server]
address = "0.0.0.0"
port = 5555

[[server.users]]
name = "operator"
token = "supersecrettoken"
```

The token value can be set to anything. However, the client will need to use the same token when connecting to the `probe-rs` server.

Finally, the `probe-rs` server can be started by simply executing the following:

```sh
probe-rs serve
```

## The Dev Machine 

### Generating with `esp-generate`

To kick start the development environment, the tool (esp-generate)[https://github.com/esp-rs/esp-generate] can be used to scaffold a majority of the project. Just like `probe-rs`, `esp-generate` can easily be fetched from `nixpkgs`.

So, to get things going, simply run the following:

```sh
nix-shell -p esp-generate
esp-generate --chip esp32c6 esp32-rust-dev
```

The TUI for `esp-generate` will appear and provide some toggle options. Below is a screenshot of the options I used:

![](/api/img/esp32/esp-generate.png)

After toggling desired toggles, and pressing `s`, the tool will scaffold a majority of the project. Now we move on to creating a `flake.nix`

### `flake.nix` and `devShells`

Let's add a `flake.nix` to the project:

```nix
{
  description = "An embedded rust flake for esp32";

  inputs = {
    # As of v25.05, must use unstable to access all the necessary packages
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [
          (import rust-overlay)
          (final: prev: {
            probe-rs-with-remote = prev.probe-rs.overrideAttrs (old: {
              cargoBuildFlags = ["--features=remote"]; # Needed for probe-rs client/server functionality
            });
          })
        ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in {
        devShells.default = with pkgs;
          mkShell {
            buildInputs = let
              rustToolchain = rust-bin.stable.latest.default.override {
                extensions = ["rust-src"];
                targets = ["riscv32imac-unknown-none-elf"];
              };
            in [
              openssl
              pkg-config
              rust-analyzer
              rustToolchain
              probe-rs-with-remote
            ];
          };
      }
    );
}
```

By using `rust-overlay`, we can declare a compilation toolchain that targets `riscv32imac-unknown-none-elf`. This ensures `rustc` will automatically be able to cross-compile to our target just by entering the declarative shell environment.

Additionally, you will see `probe-rs` being overriden in an overlay. As mentioned previously, both the development machine and development server need `probe-rs` compiled with the `remote` feature.

### `.cargo/config.toml`

A `.cargo/config.toml` file was generated during the `esp-generate` step. With the default config, `probe-rs` will expect the development board to be locally available to the development machine. Instead, `probe-rs` should remotely connect to the separate instance running on my development server. So naturally, we need to modify `.cargo/config.toml`. Specifically, it's necessary to modify the line:

```
runner = "probe-rs run --chip=esp32c6 --preverify --always-print-stacktrace --no-location --catch-hardfault"
```

By appending the `--host` and `--token` arguments to the runner command as such:

```
runner = "probe-rs run --chip=esp32c6 --preverify --always-print-stacktrace --no-location --catch-hardfault --host ws://remote-server:5555 --token supersecrettoken"
```

Remember, the `--token` argument should match the token defined in the servers `.probe-rs.toml`.

## That's All

After modifying `.cargo/config.toml`, everything should be ready to go. 

To verify that things are working correct, run the following:

```
cargo run --release
```
