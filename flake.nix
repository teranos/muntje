{
  # Only the tools are pinned here. The code is never built by Nix during the
  # event, so entering the shell once is the only time Nix is in the loop.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

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
