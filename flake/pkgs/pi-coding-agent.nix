{ lib, buildNpmPackage, fetchurl }:

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.73.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-9hTRUh87tkSOQdKW1q9OcUC+ekxa844O65yuabsSdLs=";
  };

  npmDepsHash = lib.fakeHash;

  meta = {
    description = "Minimal extensible terminal coding agent";
    homepage = "https://pi.dev";
    mainProgram = "pi";
  };
}
