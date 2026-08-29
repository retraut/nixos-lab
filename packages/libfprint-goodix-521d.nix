{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  cmake,
  gtk-doc,
  doctest,
  glib,
  gusb,
  gobject-introspection,
  pixman,
  nss,
  openssl,
  libgudev,
  libfprint,
  cairo,
}:

stdenv.mkDerivation {
  pname = "libfprint-goodix-521d";
  version = "1.94.1-unstable";

  # Reverse-engineered driver previously distributed by Arch as the
  # libfprint-goodix-521d AUR package. The source is pinned for reproducibility.
  src = fetchFromGitHub {
    owner = "infinytum";
    repo = "libfprint";
    rev = "driver/goodix-521d";
    hash = "sha256-XQ4jsgILvwc/HqT2ZmnIMpTezu5VedJ1RjuY0B6gcSk=";
  };

  postPatch = ''
    sed -i "/common_cflags = cc.get_supported_arguments(\[/a \\    '-Wno-incompatible-pointer-types'," meson.build
  '';

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    cmake
    gtk-doc
    doctest
    gobject-introspection
  ];

  buildInputs = [
    glib
    gusb
    pixman
    nss
    openssl
    libgudev
    libfprint
    cairo
  ];

  mesonFlags = [
    "-Dgtk-examples=false"
    "-Ddoc=false"
    "-Dudev_rules_dir=${placeholder "out"}/lib/udev/rules.d"
    "-Dudev_hwdb_dir=${placeholder "out"}/lib/udev/hwdb.d"
  ];

  meta = {
    description = "Community libfprint driver for Goodix 27c6:521d";
    homepage = "https://github.com/infinytum/libfprint/tree/driver/goodix-521d";
    license = lib.licenses.lgpl21Only;
    platforms = lib.platforms.linux;
  };
}
