# lib/ — vendored numerics

Miking's probabilistic and matrix externals are backed by a pared-down
[Stan Math](https://github.com/stan-dev/math) together with the Boost and
Eigen subsets it needs. This directory holds the vendored source. It replaces
the previous dependency on the `owl` opam package, which pulled in OpenBLAS,
LAPACKE, and — on macOS — libomp and fftw.

The only new tool required is a **C++17 compiler**. There is nothing to
`opam install` and no system library to find.

## Layout

    vendor-root.cpp     the canonical include set: every upstream header the
                        shim is allowed to reach. Also the closure root.
    vendor.sh           regenerates everything below. Run it to bump versions.
    VENDORED.txt        provenance: exact tag and commit of each tree.
    overlay/            pruned copies of two Stan umbrella headers (see below)
    stan-math/          \
    boost/               > the transitive closure of vendor-root.cpp, nothing more
    eigen/              /
    LICENSES/           license texts for the three vendored projects

Everything except `vendor-root.cpp`, `vendor.sh` and this file is generated.
**Do not hand-edit the vendored trees.** To reach a new upstream header, add
it to `vendor-root.cpp` and re-run `vendor.sh`; to cut a new unwanted backend
edge, add it to the `PRUNE` table in `vendor.sh` and re-run. Keeping the
patches as rules rather than as edited copies is what makes the next upstream
bump a re-run instead of a merge — and it is also what keeps us compliant
with MPL-2.0, which attaches obligations to *modified* files.

## Why a subset, and how small it is

Stan Math ships about 156 MB in its own `lib/`. We vendor **~16 MB / 1150
headers**, because `vendor.sh` copies only what `vendor-root.cpp` transitively
includes:

| tree | headers | size |
|---|---|---|
| `stan-math/` | 711 | 8.3 MB |
| `eigen/` | 261 | 4.2 MB |
| `boost/` | 198 | 2.9 MB |

Not vendored, and deliberately unreachable: **SUNDIALS**, **Intel TBB**, and
**OpenCL**. Stan needs those for ODE solvers, parallel reverse-mode autodiff,
and GPU offload respectively; we use double-only `prim`, so none of it is
required. Eigen's `unsupported/` tree is also absent — Stan ships its own
`matrix_exp_pade`, so the matrix exponential comes from Stan.

## The overlay

Two Stan umbrella headers include a backend unconditionally:

| header | dropped include | backend |
|---|---|---|
| `stan/math/prim/core.hpp` | `init_threadpool_tbb` | Intel TBB |
| `stan/math/prim/err.hpp` | `check_flag_sundials` | SUNDIALS |

Nothing in `prim/` *calls* into either — `init_threadpool_tbb`'s only
reference anywhere in Stan Math is that one include line, and the SUNDIALS
flag-checking helpers are likewise reached only through the umbrella. So
`overlay/` holds copies of those two headers with the offending line removed,
and sits ahead of `stan-math/` on the include path.

If a future Stan version adds another such edge, `vendor.sh`'s final gate
fails with the missing header rather than silently pulling a new dependency.

## Licensing

| project | license |
|---|---|
| Stan Math | BSD-3-Clause |
| Boost | BSL-1.0 |
| Eigen | MPL-2.0 (plus BSD / Apache / Minpack third-party files) |

All three are compatible with Miking's MIT license and with distributing
compiled binaries. MPL-2.0 is the only copyleft and it is file-level:
unmodified use and static linking into a differently-licensed work are
explicitly fine, and §3.3 permits the larger work under other terms. We never
modify a vendored file, so no MPL-2.0 source-publication obligation arises.

Two details worth knowing, because both are easy to get wrong:

**Eigen 3.4.0 does contain some LGPL code**, and Stan Math `v5.3.0` vendors
3.4.0. It is not in our closure, and that is *enforced rather than asserted*:
every build passes `-DEIGEN_MPL2_ONLY`, which makes Eigen itself raise a
compile error if any LGPL-licensed header is reached. Keep that flag in the
shim's flags as well as in `vendor.sh`'s gate. Consequently `COPYING.LGPL` is
deliberately **not** in `LICENSES/` — shipping it would imply we distribute
LGPL code, which we do not. (Eigen 5.0.x dropped the LGPL code and the guard
along with it; if a future Stan release vendors 5.x, the flag becomes a no-op
rather than wrong.)

**Stan Math's own `licenses/` directory is stale and is not copied here.** At
`v5.3.0` it still ships LGPL v3 text as `eigen-license.txt`, and a
`dependencies.txt` naming eigen 3.3.3, boost 1.69.0 and TBB 2019_U5 — none of
which match what the repo actually vendors. `LICENSES/` here is built from the
upstream trees themselves.

One more provenance note: `Eigen/src/IterativeLinearSolvers/IncompleteLUT.h`
carries a comment saying its implementation derives from SPARSKIT, "released
under the terms of the GNU LGPL". The same comment continues that Yousef Saad
gave permission to relicense it to MPL2, the file header is MPL-2.0, and
`-DEIGEN_MPL2_ONLY` accepts it — which is Eigen's own assertion that it is
MPL2. Recorded here so a future audit does not stall on the comment.
