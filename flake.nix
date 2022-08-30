{
  inputs = {
    nixpkgs.url = "nixpkgs";
    hello.url = "https://ftp.acc.umu.se/mirror/gnu.org/gnu/hello/hello-2.3.tar.bz2";
    hello.flake = false;
  };

  outputs = { nixpkgs, hello, ... }: let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    inherit (pkgs) stdenv;

    add-substituter = pkgs.writeShellApplication {
      name = "add-substituter";
      runtimeInputs = with pkgs; [ coreutils gnugrep gnused diffutils ];
      text = builtins.readFile ./add-substituter;
    };

    copy-to-gcp = pkgs.writeShellApplication {
      name = "copy-to-gcp";
      runtimeInputs = with pkgs; [ ];
      text = builtins.readFile ./copy-to-gcp;
    };
  in {
    packages.x86_64-linux.default = stdenv.mkDerivation {
      name = "hello-nix-12";
      src = hello;
      patchPhase = ''
        sed -i 's/Hello, world!/hello, Nix!/g' src/hello.c
      '';
      #__contentAddressed = true;
    };
    apps.x86_64-linux = {
      add-substituter = {
        program = "${add-substituter}/bin/add-substituter";
        type = "app";
      };
      copy-to-gcp = {
        program = "${copy-to-gcp}/bin/copy-to-gcp";
        type = "app";
      };
    };
  };
}
