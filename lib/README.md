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

## Golden values

These are the numbers `mi-stats` produced when it replaced owl, recorded so
that the *next* change to the numerics has something to diff against. Every
value in the first table was checked against owl 1.2 and agreed to at least
12 significant digits — that is what made the migration reviewable, and it is
the property to preserve.

`dune test --root=lib/` (or `make test-mi-stats`) prints exactly these; the
test is the executable form of this table, the table is here so a reader does
not have to run it.

| call | value |
|---|---|
| `chi2_lpdf(0.5, 3)` | `-1.51551212348465` |
| `chi2_cdf(2.3659, 3)` | `0.499986109829548` |
| `chi2_ppf(0.5, 3)` | `2.36597388437534` |
| `gamma_lpdf(2, shape 2, scale 3)` | `-2.17074406344294` |
| `gamma_cdf(2, shape 2, scale 3)` | `0.144304801612347` |
| `gamma_ppf(0.5, shape 2, scale 3)` | `5.03504097004998` |
| `beta_lpdf(0.3, 2, 5)` | `0.77052480158129` |
| `normal_lpdf(0.5, 0, 1)` | `-1.04393853320467` |
| `binomial_lpmf(3, p 0.5, n 10)` | `-2.14398006281741` |
| `lomax_lpdf(1, shape 2, scale 3)` | `-1.26851132546351` |
| `lomax_lpdf(4, shape 2, scale 3)` | `-2.94735868926978` |
| `log_gamma(4.5)` | `2.45373657084244` |
| `log_combination(10, 3)` | `4.78749174278205` |
| `multinomial_lpmf([2;3;5], [0.2;0.3;0.5])` | `-2.46451596014027` |
| `dirichlet_lpdf([0.2;0.3;0.5], [1;2;3])` | `1.50407739677627` |

The gamma rows are the ones worth watching. **owl's gamma takes a scale and
so does this interface, but Stan's `gamma_*` take a rate**, so the shim
converts. A scale/rate swap is invisible to the inference-accuracy tests —
their prior is `Gamma(1.0, 1.0)`, where scale and rate coincide — which is
precisely why these fixtures use `scale = 3`.

Two behaviours are pinned alongside the values, because they are contracts
rather than numbers:

| case | result |
|---|---|
| out of support — `gamma_lpdf(-1,·)`, `beta_lpdf(1.5,·)`, `chi2_lpdf(-1,·)` | `-inf` |
| invalid parameter — `normal_lpdf(·,·,-1)`, `gamma_lpdf(·,-2,·)`, `chi2_ppf(1.5,·)` | raises `Invalid_argument` |

owl did neither: it returned plausible numbers for invalid parameters
(`binomial_rvs` with `p = NaN` gave 0, with `p = 1.5` gave 1;
`uniform_int_rvs(0,-1)` gave 0). Raising instead is a deliberate change, and
it found five latent defects in miking-dppl and TreePPL when it landed.

### Samplers

Sampler streams are **not** comparable to owl's and were never expected to be
— a different generator and different algorithms. They are recorded only as a
regression check that seeding is deterministic and unchanged:

| call, after `set_seed 42` | value |
|---|---|
| `normal_sample(0, 1)` | `-0.638713744962857` |
| `gamma_sample(shape 2, scale 1)` | `0.729653051016944` |
| `binomial_sample(p 0.5, n 10)` | `6` |
| `categorical_sample([0.2;0.3;0.5])` | `2` |
| `uniform_int_sample(3, 7)` | `5` |

Unseeded runs must stay nondeterministic: owl self-initialised at module load
and CorePPL relies on that, so `mi_stats_rng.hpp` seeds from `std::random_device`
mixed with a clock reading on first use. See the comment there.

## Performance against owl

Measured on 2026-09-11, GCC 15.2.0 / OCaml 5.3.0, 16 cores, otherwise idle;
owl 1.2 in git worktrees at the pre-migration commits. Raw CSVs, scripts and
method are in `baseline/phase9/` of the migration working directory.

**Every comparison below is paired**: for each configuration both sides are
compiled and run back-to-back, with the leading side alternating. This host's
throughput drifts by up to a factor of two over tens of minutes, so a sweep of
one side followed by a sweep of the other measures the drift and not the
change — an unpaired first attempt produced a confident "owl is 2× slower"
that dissolved entirely under interleaving. Read ratios, not seconds.

### End to end: no regression

| suite | what it stresses | ratio mi-stats/owl |
|---|---|---|
| miking-dppl precision, `gamma-poisson`, 200 000 samples, 24 configs | inference run time | **1.001** (median; min 0.914, max 1.015) |
| miking-dppl precision, `coin-iter-alter`, 24 configs | compile, runs are sub-second | 0.940 compile |
| TreePPL matrix models, 5 models, `misc/test --all-dep` | compile (~28 modes at `--particles 2`) | **0.897** (median; min 0.877, max 0.926) |
| miking bootstrap from clean | build | 242.5 s vs 239.4 s |

The precision suite is flat across every inference method — `is-lw` 22.4→22.6 s,
`smc-bpf` 39.1→38.3 s, `smc-apf` 38.1→38.1 s, `pmcmc-pimh` 45.2→45.9 s,
`mcmc-trace` 21.7→21.6 s. The TreePPL suite, which is the one that could only
have got worse, is 10% faster on all five models, with peak RSS within ±10%.

Building `lib/` costs **12.1 s and 597 MB, once per clean build of the
repository**. That does not move the high-water mark: the OCaml self-bootstrap
already peaks at 3.8 GB.

### Per compiled program: the cost is linking, not compiling

| case | owl | mi-stats |
|---|---|---|
| `mi compile` with `dist-ext` | 0.46 s | 0.42 s |
| `mi compile` without `dist-ext` | 0.27 s | 0.23 s |
| **cost of linking the numerics** | **+0.19 s** | **+0.18 s** |
| `cppl` on `gamma-poisson` | 1.20 s | 0.92 s |

This is the number that decides whether vendoring C++ into a compiler is
viable at all. Milliseconds means the prebuilt static archive is being linked;
seconds would have meant the C++ was being rebuilt per generated program. It
is milliseconds, and that is what the 10% TreePPL win is made of — ~28 compiles
per model, each linking slightly less.

### Per call: gamma and beta are ~6× dearer, categorical ~4× cheaper

Net of loop overhead, 10 000 000 calls, median of 3 pairs:

| call | owl | mi-stats | ratio |
|---|---|---|---|
| `categorical_sample` | 184 ns | 46 ns | **0.25** |
| `normal_lpdf` | 3.1 ns | 2.8 ns | 0.90 |
| `gamma_lpdf` | 10.5 ns | 10.3 ns | 0.98 |
| `exponential_sample` | 3.6 ns | 5.6 ns | 1.56 |
| `uniform_sample` | 2.4 ns | 4.9 ns | 2.04 |
| `normal_sample` | 3.6 ns | 7.6 ns | 2.11 |
| `binomial_sample` | 12.1 ns | 33.7 ns | 2.79 |
| `binomial_lpmf` | 14.0 ns | 68.8 ns | 4.91 |
| `beta_sample` | 20.4 ns | 126 ns | **6.17** |
| `gamma_sample` | 10.3 ns | 65.8 ns | **6.39** |

The densities are level; the samplers are not. `beta_sample` is two gamma
draws and inherits gamma's cost. The likely cause is per-call construction:
`mi_stats_dist.cpp` calls `stan::math::gamma_rng`, which builds a fresh
`variate_generator<RNG&, gamma_distribution<>>` and runs Stan's argument checks
on every draw, where owl called a hand-written sampler. **If a gamma- or
beta-heavy model ever shows a regression, hoisting that construction out of
the per-draw path is the first thing to try** — nothing measured here needs it.

Matrix operations, same method: `matrixExponential` **0.24×** (4.2× faster),
`matrixMul` 1.10×.

### Why the per-call numbers do not show up end to end

In the precision suite one sample costs ~113 µs of interpreter work, so tens
of nanoseconds per draw is invisible. Where inference genuinely dominates —
TreePPL diversification models at real particle counts — a small cost does
surface:

| model | particles | owl median | mi-stats median | ratio |
|---|---|---|---|---|
| `crbd` | 100 000 | 8.80 s | 9.29 s | 1.055 |
| `clads2` | 100 000 | 12.30 s | 13.54 s | 1.101 |
| `bdd2` | 20 000 | 9.38 s | 11.53 s | 1.229 |

Treat `bdd2`'s figure with care, and prefer the minima (owl 7.61 s,
mi-stats 7.41 s) over its median. These models simulate a stochastic process,
so the *amount of work* depends on the draws: with different RNG streams the
two sides do not execute the same computation, and the distribution is
heavy-tailed — across nine runs of the same owl binary `bdd2` ranged from
7.61 s to 151 s. `crbd` and `clads2` are well behaved (owl min 8.61 s / 11.51 s
against mi-stats 9.14 s / 12.60 s) and their 5–10% is real.

So: flat where work per sample is fixed, 5–10% dearer in sampler-bound
inference, 10% cheaper anywhere compilation dominates.
