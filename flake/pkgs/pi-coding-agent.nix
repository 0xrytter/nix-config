{ lib, buildNpmPackage, fetchFromGitHub }:

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.73.0";

  src = fetchFromGitHub {
    owner = "badlogic";
    repo = "pi-mono";
    rev = "v${version}";
    hash = "sha256-oE4zMH5KEH185Vdp0CE221sa9rJJw35jFLlfhTa3Sg4=";
  };

  sourceRoot = "${src.name}/packages/coding-agent";

  npmDepsHash = lib.fakeHash;

  meta = {
    description = "Minimal extensible terminal coding agent";
    homepage = "https://pi.dev";
    mainProgram = "pi";
  };
}
