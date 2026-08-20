{ lib
, stdenvNoCC
, fetchurl
, makeBinaryWrapper
, bubblewrap
, ripgrep
}:

stdenvNoCC.mkDerivation rec {
  pname = "codex";
  version = "0.148.0";

  codexHash = "sha256-Gjb3YvazvvUzu4Y0WtlRdmHC2E1TmWolDPLKidLP7lo=";
  hostHash = "sha256-jm5VmyKPphsY+ywowx7AIGh1ECW8zj8Az2PHlJnVmCk=";

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
    wrapProgram "$out/bin/codex" --prefix PATH : "${lib.makeBinPath [ bubblewrap ripgrep ]}"
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = [ "x86_64-linux" ];
  };
}
