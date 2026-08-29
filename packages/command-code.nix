{ lib
, stdenvNoCC
, fetchurl
, buildNpmPackage
, nodejs
, makeWrapper
, gnutar
}:

let
  version = "1.29.0";

  source = stdenvNoCC.mkDerivation {
    pname = "command-code-source";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmjs.org/command-code/-/command-code-${version}.tgz";
      hash = "sha512-oORRiUzjmnZFfduZtH10XmzoWGlS0lOgtKh2L2ti8iWVKnIXGABL/WUYnetsYcHt1zukc2xQnGGOCH7UlFgh2g==";
    };

    nativeBuildInputs = [ gnutar ];
    dontUnpack = true;

    installPhase = ''
      mkdir -p "$out"
      tar -xzf "$src" -C "$out" --strip-components=1
      cp ${./command-code/package.json} "$out/package.json"
      cp ${./command-code/package-lock.json} "$out/package-lock.json"
    '';
  };
in

buildNpmPackage {
  pname = "command-code";
  inherit version;
  src = source;

  npmDepsHash = "sha256-6keAHd/gvNsIslFXcVQBWO6D/S+P2iJl2b2Cmxt9Qko=";
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -d "$out/lib/node_modules/command-code" "$out/bin"
    cp -r ./* "$out/lib/node_modules/command-code/"

    for name in cmd cmdc command-code commandcode; do
      makeWrapper ${nodejs}/bin/node "$out/bin/$name" \
        --add-flags "$out/lib/node_modules/command-code/dist/index.mjs"
    done
  '';

  meta = {
    description = "Command Code AI coding agent";
    homepage = "https://commandcode.ai/";
    mainProgram = "cmd";
    platforms = lib.platforms.linux;
  };
}
