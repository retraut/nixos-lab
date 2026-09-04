{ lib
, stdenvNoCC
, fetchurl
, makeBinaryWrapper
, bubblewrap
, ripgrep
, nodejs
}:

stdenvNoCC.mkDerivation rec {
  pname = "codex";
  version = "0.153.3";

  codexHash = "sha256-b/lnS7AOFHNMJ0i8h4jqs8tuWsU+vefh54C07Xr0jLo=";
  hostHash = "sha256-EK5jMEXSjZ1dzWqnXYSYaOPOn+pu9OZp61HRJMaa71M=";

  codexSrc = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
    hash = codexHash;
  };

  hostSrc = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz";
    hash = hostHash;
  };

  nativeBuildInputs = [ makeBinaryWrapper ];
  dontUnpack = true;

  installPhase = ''
    install -d "$out/bin"
    tar -xzf "$codexSrc" -C "$out/bin"
    mv "$out/bin/codex-x86_64-unknown-linux-musl" "$out/bin/codex"
    tar -xzf "$hostSrc" -C "$out/bin"
    mv "$out/bin/codex-code-mode-host-x86_64-unknown-linux-musl" "$out/bin/codex-code-mode-host"
  '';

  postFixup = ''
    wrapProgram "$out/bin/codex" \
      --set CODEX_MCP_NODE_PATH "${nodejs}/bin/node" \
      --prefix PATH : "${lib.makeBinPath [ bubblewrap ripgrep ]}"
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = [ "x86_64-linux" ];
  };
}
