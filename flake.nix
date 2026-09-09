{
  description = "Dust GUI development environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.nixpkgs-intel-mac.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
  inputs.gui = { url = "github:vlang/gui"; flake = false; };
  inputs.vglyph = { url = "github:vlang/vglyph"; flake = false; };
  outputs = { self, nixpkgs, nixpkgs-intel-mac, gui, vglyph }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
    in {
      devShells = eachSystem (system:
        let source = if system == "x86_64-darwin" then nixpkgs-intel-mac else nixpkgs;
            pkgs = import source { inherit system; };
            guiPatched = pkgs.runCommand "dust-atlas-gui" { nativeBuildInputs = [ pkgs.patch ]; } ''
              cp -R ${gui} $out
              chmod -R u+w $out
              cd $out
              patch -p1 < ${./patches/gui-macos-input.patch}
              patch -p1 < ${./patches/gui-macos-performance.patch}
              patch -p1 < ${./patches/gui-tree-context.patch}
              patch -p1 < ${./patches/gui-tree-selection.patch}
            '';
            vglyphPatched = pkgs.runCommand "dust-atlas-vglyph" { nativeBuildInputs = [ pkgs.patch ]; } ''
              cp -R ${vglyph} $out
              chmod -R u+w $out
              cd $out
              patch -p1 < ${./patches/vglyph-macos-paste.patch}
            '';
            modules = pkgs.linkFarm "dust-atlas-v-modules" [
              { name = "gui"; path = guiPatched; }
              { name = "vglyph"; path = vglyphPatched; }
              { name = "json2"; path = "${pkgs.vlang}/lib/vlib/x/json2"; }
            ];
            # macOS frameworks exceed the default Boehm static-root limit, so
            # plain `v run .` needs the same GC flags as scripts/build.vsh.
            gcFlags = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin
              " -d use_bundled_libgc -cflags -DLARGE_CONFIG";
        in { default = pkgs.mkShell {
          VFLAGS = "-path ${modules}|@vlib|@vmodules${gcFlags}";
          packages = [ pkgs.python3 pkgs.vlang pkgs.dust pkgs.pkg-config pkgs.pango pkgs.harfbuzz pkgs.fribidi pkgs.fontconfig pkgs.freetype pkgs.libsysprof-capture pkgs.pcre2 pkgs.libthai pkgs.libdatrie pkgs.libxdmcp ]
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.dbus pkgs.libGL pkgs.libx11 pkgs.libxi pkgs.libxcursor pkgs.libxrandr pkgs.util-linux pkgs.systemdLibs pkgs.libselinux pkgs.libsepol ];
        }; });
    };
}
