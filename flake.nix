{
  description = "A basic flake using uv2nix";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/24.05";
    uv2nix.url = "github:/adisbladis/uv2nix";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    nixpkgs,
    uv2nix,
    ...
  }: let
    inherit (nixpkgs) lib;

    workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};

    pkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };

    # Manage overlays
    overlay = let
      # Create overlay from workspace.
      overlay' = workspace.mkOverlay {
        sourcePreference = "wheel";
      };
      # work around for packaging must-not-be-a-wheel and is best not overwritten
      overlay'' = pyfinal: pyprev: let
        applied = overlay' pyfinal pyprev;
      in
        lib.filterAttrs (n: _: n != "packaging" && n != "tomli" && n != "pyproject-hooks" && n != "build" && n != "wheel") applied;

      overrides = final: prev: {
        sgmllib3k = prev.sgmllib3k.overridePythonAttrs (old: {nativeBuildInputs = old.nativeBuildInputs or [] ++ [final.setuptools];});
        tarjan = prev.tarjan.overridePythonAttrs (old: {nativeBuildInputs = old.nativeBuildInputs or [] ++ [final.setuptools];});
      };
    in
      lib.composeExtensions overlay'' overrides;

    python = pkgs.python39.override {
      self = python;
      packageOverrides = overlay;
    };
  in {
    packages.x86_64-linux.default = python.pkgs.app;
    # TODO: A better mkShell withPackages example.
  };
}
