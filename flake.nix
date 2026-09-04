{
  # Only the tools are pinned here. The code is never built by Nix during the
  # event, so entering the shell once is the only time Nix is in the loop.
  # unstable, because tm20 needs a rustc newer than 25.05 carries. The lock
  # pins the exact commit.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.foundry
          pkgs.cargo
          pkgs.rustc
        ];
      };
    };
}
