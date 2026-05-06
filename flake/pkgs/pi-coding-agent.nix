{ lib, buildNpmPackage, fetchFromGitHub, nodejs, makeWrapper, pkg-config, pixman, cairo, pango, libjpeg, giflib, librsvg }:

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.73.0";

  src = fetchFromGitHub {
    owner = "badlogic";
    repo = "pi-mono";
    rev = "v${version}";
    hash = "sha256-oE4zMH5KEH185Vdp0CE221sa9rJJw35jFLlfhTa3Sg4=";
  };

  npmDepsHash = "sha256-rBlAzAnP9aif1tZ984AO4HftIJsDgLQ+02J3td4jcRg=";

  buildPhase = ''
    npm run build --workspace=packages/coding-agent
  '';

  installPhase = ''
    mkdir -p $out/bin $out/lib/pi
    cp -r packages/coding-agent/dist $out/lib/pi/
    cp -r packages/coding-agent/package.json $out/lib/pi/
    makeWrapper ${nodejs}/bin/node $out/bin/pi \
      --add-flags "$out/lib/pi/dist/cli.js"
  '';

  nativeBuildInputs = [ makeWrapper pkg-config ];
  buildInputs = [ pixman cairo pango libjpeg giflib librsvg ];

  meta = {
    description = "Minimal extensible terminal coding agent";
    homepage = "https://pi.dev";
    mainProgram = "pi";
  };
}
