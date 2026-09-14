(define-module (miking)
  #:use-module (guix build-system dune)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system ocaml)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages ocaml))

(define-public ocaml-ISO8601
  ;; NOTE: Using commit from master branch as 0.2.6 uses the Pervasives
  ;; module in its tests, which is incompatible with OCaml 5.0.
  (let ((revision "0")
        (commit "ad50cb01061405623c834608c26f1ef2d44f8340"))
    (package
      (name "ocaml-ISO8601")
      (version (git-version "0.2.6" revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://github.com/ocaml-community/ISO8601.ml")
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "1lvjrxz66b7dv40cbl8xyfv3x8nmwj0m5ipfvxc37mjaaf3xrr5g"))))
      (build-system dune-build-system)
      (propagated-inputs (list ocaml-odoc))
      (native-inputs (list ocaml-ounit))
      (home-page "https://github.com/ocaml-community/ISO8601.ml/")
      (synopsis "ISO 8601 and RFC 3339 date parsing for OCaml")
      (description
       "OCaml parser and printer for date-times in ISO8601 and RFC 3339")
      (license license:expat))))

(define-public ocaml-ocb
  (package
    (name "ocaml-ocb")
    (version "0.2")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/OCamlPro/ocb")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "1nk90jax91ld8qd36qi408mll8a7w1d60fa2qdsnff7cldwixc1d"))))
    (build-system dune-build-system)
    (propagated-inputs (list ocaml-odoc))
    (home-page "https://ocamlpro.github.io/ocb/")
    (synopsis "SVG badge generator")
    (description
     "An OCaml library for SVG badge generation.  There's also a command-line tool
provided.")
    (license license:isc)))

(define-public ocaml-toml
  (package
    (name "ocaml-toml")
    (version "7.1.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/ocaml-toml/to.ml")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0z2873mj3i6h9cg8zlkipcjab8jympa4c4avhk4l04755qzphkds"))))
    (build-system dune-build-system)
    (propagated-inputs (list ocaml-odoc ocaml-ISO8601))
    (native-inputs
     (list ocaml-menhir ocaml-ounit2 ocaml-mdx ocaml-bisect-ppx ocaml-ocb))
    (home-page "https://ocaml-toml.github.io/To.ml/")
    (synopsis "Library for TOML with a parser, a serializer and a printer")
    (description
     "toml is an OCaml library providing a parser, a serializer and a printer for
TOML, a minimal configuration file format.  Helpful getters to retrieve data as
OCaml primitive types are also supplied.")
    (license license:lgpl3)))

(define-syntax-rule (and/fn functions ...)
  (lambda args (and (apply functions args) ...)))

(define %miking-root ((compose dirname dirname dirname) current-filename))

(define-public miking
  (package
    (name "miking")
    (version "0.0.0+git")
    (source
     (local-file %miking-root
                 #:recursive? #t
                 #:select?
                 (and/fn (git-predicate %miking-root)
                         (lambda (file stat)
                           (not (string-contains file "misc/packaging"))))))
    (build-system dune-build-system)
    (arguments
     (list #:modules '((guix build utils)
                       (guix build dune-build-system)
                       ((guix build gnu-build-system) #:prefix gnu:))
           #:test-target "test-compile"
           #:phases
           #~(modify-phases %standard-phases
               (add-before 'build 'set-prefix
                 (lambda* (#:key outputs #:allow-other-keys)
                   (setenv "prefix" (assoc-ref outputs "out"))))
               (replace 'build (assoc-ref gnu:%standard-phases 'build))
               (replace 'check (assoc-ref gnu:%standard-phases 'check))
               (replace 'install (assoc-ref gnu:%standard-phases 'install))
               (add-after 'install 'wrap
                 (lambda* (#:key inputs outputs #:allow-other-keys)
                   ;; NOTE: `mi-stats` is installed by `make install` into this
                   ;; package's own `lib/ocaml/site-lib` (the Makefile derives
                   ;; `ocamllibdir` from `prefix`, set above).  It has to be on
                   ;; OCAMLPATH as well as installed, or `mi compile` of a
                   ;; program using `dist-ext.mc`, `math-ext.mc` or
                   ;; `matrix-ext.mc` fails to find the package.  owl was a
                   ;; native-input and so was never on this list either, which
                   ;; means that path could not have worked before.
                   (wrap-program (string-append (assoc-ref outputs "out") "/bin/mi")
                     `("PATH" suffix (,(dirname (search-input-file inputs "bin/mkdir"))))
                     `("OCAMLPATH" suffix
                       (,(string-append (assoc-ref outputs "out") "/lib/ocaml/site-lib")
                        ,(string-append (assoc-ref inputs "ocaml-linenoise")
                                        "/lib/ocaml/site-lib")))))))))
    (inputs
     (list
      ocaml-linenoise
      coreutils         ;; Miking currently requires mkdir to be able to run
      ))
    (native-inputs
     (list
      ocaml-lwt         ;; For async-ext.mc
      ocaml-toml        ;; For toml-ext.mc
      ;; NOTE: there is no package to add for the numerics any more.  What
      ;; owl used to provide is now built from the vendored sources in
      ;; `lib/` by the repository's own dune project, as part of the default
      ;; `make` target, and installed by `make install` -- so it needs only a
      ;; C++ compiler, which the build environment already has.
      ))
    (synopsis "Meta language system for creating embedded DSLs.")
    (description "Miking (Meta vIKING) is a meta language system for creating
embedded domain-specific and general-purpose languages.  The system features
a polymorphic core calculus and a DSL definition language where languages
can be extended and composed from smaller fragments.

Note: Depending on the target runtime, miking requires the presence of
additional packages within an environment, such as dune, ocaml, ocaml-findlib
and gcc-toolchain for native builds, node for javascript, and a suitable JDK
when targeting the JVM.")
    (home-page "https://miking.org")
    (license license:expat)))

;; For `guix build -f'
(package-with-ocaml5.0 miking)
