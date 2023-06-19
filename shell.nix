{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    (pkgs.stdenv.mkDerivation rec {
      name = "zig";
      src = pkgs.fetchurl {
        url = "https://ziglang.org/builds/zig-linux-x86_64-0.11.0-dev.3395+1e7dcaa3a.tar.xz";
        sha256 = "YGea64CkX11em1hoLfYpLT0Qj+UbhPik98EqcImGQO4=";
      };
      installPhase = ''
        mkdir -p $out/bin
        mv * $out/bin
        '';
    })
    SDL2
    pkgconfig
  ];
}
