{ lib, buildNpmPackage, fetchurl }:

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.73.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-1fvl2axnkblwxc78xwss9ixbwh3i9spxd5nj86749div3x9d257n=";
  };

  npmDepsHash = lib.fakeHash;

  meta = {
    description = "Minimal extensible terminal coding agent";
    homepage = "https://pi.dev";
    mainProgram = "pi";
  };
}
