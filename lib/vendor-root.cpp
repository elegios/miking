// Canonical include set for Miking's vendored numerics.
//
// This file has one job: name every upstream header the shim in lib/mi-stats/
// is allowed to reach. `vendor.sh` uses it as the root for `g++ -M`, and the
// transitive closure of these includes is exactly what gets copied into
// lib/{stan-math,boost,eigen}. Nothing else is vendored.
//
// So: adding a capability to the shim means adding its header here and
// re-running vendor.sh. If you include something the closure does not cover,
// the build fails with a missing header rather than silently reaching outside
// lib/ -- which is the property we want.
//
// Deliberately absent:
//   * Anything under stan/math/rev/ or stan/math/fwd/. We use double-only
//     `prim`; Stan's reverse-mode autodiff is what makes it need TBB, and we
//     have no use for gradients today.
//   * unsupported/Eigen/MatrixFunctions. Stan ships its own matrix_exp_pade,
//     so expm comes from Stan and Eigen's unsupported/ tree is never needed.
//   * stan/math/prim.hpp and the other umbrella headers, which pull in ODE
//     solvers (Sundials) and the TBB threadpool init. See lib/overlay/.

// ---- distributions: log densities and CDFs -------------------------------
#include <stan/math/prim/prob/beta_lpdf.hpp>
#include <stan/math/prim/prob/binomial_lpmf.hpp>
#include <stan/math/prim/prob/chi_square_cdf.hpp>
#include <stan/math/prim/prob/chi_square_lpdf.hpp>
#include <stan/math/prim/prob/dirichlet_lpdf.hpp>
#include <stan/math/prim/prob/gamma_cdf.hpp>
#include <stan/math/prim/prob/gamma_lpdf.hpp>
#include <stan/math/prim/prob/multinomial_lpmf.hpp>
#include <stan/math/prim/prob/normal_lpdf.hpp>
#include <stan/math/prim/prob/pareto_type_2_lpdf.hpp>  // Lomax: mu = 0

// ---- distributions: samplers --------------------------------------------
#include <stan/math/prim/prob/beta_rng.hpp>
#include <stan/math/prim/prob/binomial_rng.hpp>
#include <stan/math/prim/prob/categorical_rng.hpp>
#include <stan/math/prim/prob/chi_square_rng.hpp>
#include <stan/math/prim/prob/dirichlet_rng.hpp>
#include <stan/math/prim/prob/exponential_rng.hpp>
#include <stan/math/prim/prob/gamma_rng.hpp>
#include <stan/math/prim/prob/multinomial_rng.hpp>
#include <stan/math/prim/prob/normal_rng.hpp>
#include <stan/math/prim/prob/pareto_type_2_rng.hpp>
#include <stan/math/prim/prob/uniform_rng.hpp>

// ---- special functions (math-ext) ---------------------------------------
#include <stan/math/prim/fun/binomial_coefficient_log.hpp>  // log_combination
#include <stan/math/prim/fun/lgamma.hpp>                    // loggamma

// ---- matrix operations (mat-ext, matrix-ext) ----------------------------
#include <stan/math/prim/fun/matrix_exp.hpp>  // expm, via Stan's own Pade

// ---- Boost: the quantiles Stan does not have (chi2_ppf, gamma_ppf) ------
#include <boost/math/distributions/chi_squared.hpp>
#include <boost/math/distributions/gamma.hpp>

// ---- Boost: the RNG engine we own, and discrete uniform -----------------
// Stan's *_rng functions take an engine by reference, so setSeed reseeds this
// one generator instead of owl's four.
#include <boost/random/mersenne_twister.hpp>
#include <boost/random/uniform_int_distribution.hpp>

// ---- Eigen: matrix ops and the CBLAS-shaped routines --------------------
#include <Eigen/Dense>

int main() { return 0; }
