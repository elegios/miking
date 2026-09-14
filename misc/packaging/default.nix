import <nixpkgs> {
  overlays =
    [ (pkgs-self: pkgs-super:
      { ocamlPackages =
          let
            # NOTE: OCaml 5.0.0 predates C23.  `ocamlc -output-complete-exe`
            # (and anything else that links a custom runtime) emits
            # declarations of the form
            #
            #     extern value caml_get_public_method();
            #
            # where empty parentheses meant "unspecified arguments".  In C23
            # they mean `(void)`, so these now conflict with the real
            # prototypes in `caml/mlvalues.h` and the compile fails with
            # `conflicting types for 'caml_get_public_method'`.  GCC 15
            # defaults to C23, so against a recent nixpkgs the whole OCaml
            # 5.0.0 scope stops building -- dune's own bootstrap
            # (`_boot/dune.exe`) hits it first and takes every dependent
            # derivation with it.
            #
            # This is the same class of problem as the `-std=gnu17` that owl
            # 1.2 needed under GCC 15, and it is unrelated to the owl removal:
            # the identical `dune-3.21.1.drv` fails from the pre-migration
            # tree.  `flake.nix` never hit it because it uses nixpkgs'
            # default `ocamlPackages` rather than pinning 5.0.
            #
            # The pin to 5.0 is what forces the workaround.  If that pin is
            # ever lifted -- note `miking-pack-{linux,darwin}` hardcode
            # `lib/ocaml/5.0.0/site-lib` and would have to move in step --
            # this whole `let` can go.
            withC23Fix = scope: scope.overrideScope (ocaml-self: ocaml-super: {
              dune_3 = ocaml-super.dune_3.overrideAttrs (previousAttrs: {
                NIX_CFLAGS_COMPILE =
                  (previousAttrs.NIX_CFLAGS_COMPILE or "") + " -std=gnu17";
              });
            });
            base = withC23Fix pkgs-super.ocaml-ng.ocamlPackages_5_0;
          in
          if pkgs-super.stdenv.isDarwin then
            # NOTE: The `eigen`, `owl-base` and `owl`
            # overrides that used to live here are gone along with the owl
            # dependency itself; the numerics support library `mi-stats` is
            # built from vendored sources in `lib/` and needs no package of
            # its own.  Only the `ocaml` fix remains.
            #
            # `overrideScope` here (and above) was spelt `overrideScope'` until
            # recently; the primed name is gone from current nixpkgs, so that
            # spelling no longer evaluates at all.  This branch is lazy and so
            # never evaluated on Linux, which is why the breakage went unseen.
            base.overrideScope (ocaml-self: ocaml-super: {
              ocaml = ocaml-super.ocaml.overrideAttrs (finalAttrs: previousAttrs: {
                preConfigure = ''AS="cc -c" ASPP="cc -c"'';
              });
            })
          else
            base;
        # NOTE: `miking.nix` takes `miking-lib` and `miking-unwrapped` as
        # arguments, so both have to exist in the overlay for `callPackage` to
        # find them.  Without these two lines `nix-build -A miking` aborts with
        # `Function called without required argument "miking-lib"`, which also
        # breaks `miking-pack-{linux,darwin}`: they resolve their `miking`
        # top-dep through exactly this file.  `flake.nix` passes them
        # explicitly and so never hit it.
        miking-lib = with pkgs-self; callPackage (import ./miking-lib.nix) {};
        miking-unwrapped = with pkgs-self; callPackage (import ./miking-unwrapped.nix) {};
        miking = with pkgs-self; callPackage (import ./miking.nix) {};
        miking-shell = pkgs-super.mkShell {
          buildInputs = [ pkgs-self.miking ];
        };
      })
    ];
}
