// dist-ext: densities, CDFs and samplers for the eight families Miking uses.
//
// Parameterisation traps, all of which bit during the spike:
//   * owl's gamma takes a SCALE; Stan's gamma_lpdf/cdf/rng take a RATE.
//     Converted here as 1/scale. Boost's gamma_distribution (used for the
//     quantile in mi_stats_special.cpp) takes a scale, so that one does not
//     convert -- the two go in opposite directions in adjacent files.
//   * owl's binomial_logpdf is (k, ~p, ~n); Stan's binomial_lpmf is (k, N, p).
//   * Lomax is Pareto Type II, i.e. pareto_type_2 with mu = 0. owl's own
//     lomax_logpdf/cdf/ppf implement Pareto Type *I* instead (support x >=
//     scale) while its lomax_rvs is a true Lomax, so owl's sampler and
//     density were for different distributions. Miking already worked around
//     that with a hand-written MExpr density; Stan agrees with the MExpr one.
//   * Stan's categorical_rng is 1-based; owl's categorical_rvs is 0-based.
#include "mi_stats_common.hpp"
#include "mi_stats_rng.hpp"

#include <stan/math/prim/prob/beta_lpdf.hpp>
#include <stan/math/prim/prob/beta_rng.hpp>
#include <stan/math/prim/prob/binomial_lpmf.hpp>
#include <stan/math/prim/prob/binomial_rng.hpp>
#include <stan/math/prim/prob/categorical_rng.hpp>
#include <stan/math/prim/prob/chi_square_cdf.hpp>
#include <stan/math/prim/prob/chi_square_lpdf.hpp>
#include <stan/math/prim/prob/chi_square_rng.hpp>
#include <stan/math/prim/prob/dirichlet_lpdf.hpp>
#include <stan/math/prim/prob/dirichlet_rng.hpp>
#include <stan/math/prim/prob/exponential_rng.hpp>
#include <stan/math/prim/prob/gamma_cdf.hpp>
#include <stan/math/prim/prob/gamma_lpdf.hpp>
#include <stan/math/prim/prob/gamma_rng.hpp>
#include <stan/math/prim/prob/multinomial_lpmf.hpp>
#include <stan/math/prim/prob/multinomial_rng.hpp>
#include <stan/math/prim/prob/normal_lpdf.hpp>
#include <stan/math/prim/prob/normal_rng.hpp>
#include <stan/math/prim/prob/pareto_type_2_lpdf.hpp>
#include <stan/math/prim/prob/pareto_type_2_rng.hpp>
#include <stan/math/prim/prob/uniform_rng.hpp>

#include <boost/random/uniform_int_distribution.hpp>

#include <Eigen/Dense>

#include <caml/alloc.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

#include <vector>

namespace {

// OCaml `float array` is a flat unboxed block.
inline int float_array_len(value v) {
  return static_cast<int>(Wosize_val(v) / Double_wosize);
}
inline void read_float_array(value v, std::vector<double> &out) {
  const int n = float_array_len(v);
  out.resize(n);
  for (int i = 0; i < n; ++i) out[i] = Double_field(v, i);
}
inline Eigen::VectorXd to_eigen(const std::vector<double> &v) {
  return Eigen::Map<const Eigen::VectorXd>(v.data(), v.size());
}

}  // namespace

extern "C" {

// ===========================================================================
// Scalar densities and CDFs
// ===========================================================================

double mi_chi2_lpdf(double x, double df) {
  if (!mi::positive(df)) return mi::invalid;
  MI_SUPPORT(stan::math::chi_square_lpdf(x, df))
}
// A CDF saturates outside the support -- 0 below, 1 above -- so MI_SUPPORT's
// -inf is the wrong answer here. Both families are supported on [0, inf), and
// gammaPpf(1) legitimately hands these functions +inf (see mi_stats_special).
double mi_chi2_cdf(double x, double df) {
  if (!mi::positive(df)) return mi::invalid;
  if (std::isnan(x)) return mi::invalid;
  if (x <= 0.0) return 0.0;
  if (std::isinf(x)) return 1.0;
  try { return stan::math::chi_square_cdf(x, df); } catch (...) { return 1.0; }
}
double mi_gamma_lpdf(double x, double shape, double scale) {
  if (!mi::positive(shape) || !mi::positive(scale)) return mi::invalid;
  MI_SUPPORT(stan::math::gamma_lpdf(x, shape, 1.0 / scale))
}
double mi_gamma_cdf(double x, double shape, double scale) {
  if (!mi::positive(shape) || !mi::positive(scale)) return mi::invalid;
  if (std::isnan(x)) return mi::invalid;
  if (x <= 0.0) return 0.0;
  if (std::isinf(x)) return 1.0;
  try { return stan::math::gamma_cdf(x, shape, 1.0 / scale); }
  catch (...) { return 1.0; }
}
double mi_beta_lpdf(double x, double a, double b) {
  if (!mi::positive(a) || !mi::positive(b)) return mi::invalid;
  MI_SUPPORT(stan::math::beta_lpdf(x, a, b))
}
double mi_normal_lpdf(double x, double mu, double sigma) {
  if (!std::isfinite(mu) || !mi::positive(sigma)) return mi::invalid;
  MI_SUPPORT(stan::math::normal_lpdf(x, mu, sigma))
}
// Available but currently unused: `externalLomaxLogPdf` is deleted, because
// dist-ext.mc computes the Lomax density in MExpr. Kept so that binding can
// be reinstated against Stan if wanted -- the two agree.
double mi_lomax_lpdf(double x, double shape, double scale) {
  if (!mi::positive(shape) || !mi::positive(scale)) return mi::invalid;
  MI_SUPPORT(stan::math::pareto_type_2_lpdf(x, 0.0, scale, shape))
}

// ===========================================================================
// Scalar samplers
// ===========================================================================

double mi_chi2_sample(double df) {
  if (!mi::positive(df)) return mi::invalid;
  MI_SUPPORT(stan::math::chi_square_rng(df, mi::engine()))
}
double mi_gamma_sample(double shape, double scale) {
  if (!mi::positive(shape) || !mi::positive(scale)) return mi::invalid;
  MI_SUPPORT(stan::math::gamma_rng(shape, 1.0 / scale, mi::engine()))
}
double mi_beta_sample(double a, double b) {
  if (!mi::positive(a) || !mi::positive(b)) return mi::invalid;
  MI_SUPPORT(stan::math::beta_rng(a, b, mi::engine()))
}
double mi_normal_sample(double mu, double sigma) {
  if (!std::isfinite(mu) || !mi::positive(sigma)) return mi::invalid;
  MI_SUPPORT(stan::math::normal_rng(mu, sigma, mi::engine()))
}
double mi_exponential_sample(double lambda) {  // rate, as in owl
  if (!mi::positive(lambda)) return mi::invalid;
  MI_SUPPORT(stan::math::exponential_rng(lambda, mi::engine()))
}
double mi_uniform_sample(double a, double b) {
  if (!std::isfinite(a) || !std::isfinite(b) || !(a <= b)) return mi::invalid;
  if (a == b) return a;  // Stan rejects a degenerate range; owl returned a
  MI_SUPPORT(stan::math::uniform_rng(a, b, mi::engine()))
}
double mi_lomax_sample(double shape, double scale) {
  if (!mi::positive(shape) || !mi::positive(scale)) return mi::invalid;
  MI_SUPPORT(stan::math::pareto_type_2_rng(0.0, scale, shape, mi::engine()))
}

// ===========================================================================
// Mixed int/float and array-valued entry points
// ===========================================================================

// owl: binomial_logpdf : int -> p:float -> n:int -> float
CAMLprim value mi_binomial_lpmf(value vk, value vp, value vn) {
  const long k = Long_val(vk), n = Long_val(vn);
  const double p = Double_val(vp);
  if (n < 0 || !mi::probability(p))
    caml_invalid_argument("mi_binomial_lpmf: require n >= 0 and 0 <= p <= 1");
  double r;
  if (k < 0 || k > n) {
    r = mi::neg_inf;  // out of support
  } else {
    try {
      r = stan::math::binomial_lpmf(static_cast<int>(k), static_cast<int>(n), p);
    } catch (...) {
      r = mi::neg_inf;
    }
  }
  return caml_copy_double(r);
}

// owl: binomial_rvs : p:float -> n:int -> int
CAMLprim value mi_binomial_sample(value vp, value vn) {
  const long n = Long_val(vn);
  const double p = Double_val(vp);
  if (n < 0 || !mi::probability(p))
    caml_invalid_argument("mi_binomial_sample: require n >= 0 and 0 <= p <= 1");
  try {
    return Val_long(stan::math::binomial_rng(static_cast<int>(n), p, mi::engine()));
  } catch (...) {
    caml_failwith("mi_binomial_sample: sampler failed");
  }
}

// owl: uniform_int_rvs : int -> int -> int (inclusive). Stan has no discrete
// uniform, so this is Boost.Random directly.
CAMLprim value mi_uniform_int_sample(value va, value vb) {
  const long a = Long_val(va), b = Long_val(vb);
  if (a > b) caml_invalid_argument("mi_uniform_int_sample: require a <= b");
  boost::random::uniform_int_distribution<long> d(a, b);
  return Val_long(d(mi::engine()));
}

// owl: categorical_rvs : float array -> int, 0-based.
// Stan's categorical_rng is 1-based, hence the -1.
CAMLprim value mi_categorical_sample(value vp) {
  std::vector<double> p;
  read_float_array(vp, p);
  if (!mi::simplex(p.data(), static_cast<int>(p.size())))
    caml_invalid_argument("mi_categorical_sample: probabilities must be a simplex");
  try {
    return Val_long(stan::math::categorical_rng(to_eigen(p), mi::engine()) - 1);
  } catch (...) {
    caml_failwith("mi_categorical_sample: sampler failed");
  }
}

// owl: multinomial_logpdf : int array -> p:float array -> float
CAMLprim value mi_multinomial_lpmf(value vns, value vp) {
  std::vector<double> p;
  read_float_array(vp, p);
  const int k = static_cast<int>(Wosize_val(vns));
  if (!mi::simplex(p.data(), static_cast<int>(p.size())) ||
      k != static_cast<int>(p.size()))
    caml_invalid_argument(
        "mi_multinomial_lpmf: probabilities must be a simplex of the same length");
  std::vector<int> ns(k);
  for (int i = 0; i < k; ++i) {
    const long c = Long_val(Field(vns, i));
    if (c < 0) return caml_copy_double(mi::neg_inf);  // out of support
    ns[i] = static_cast<int>(c);
  }
  double r;
  try {
    r = stan::math::multinomial_lpmf(ns, to_eigen(p));
  } catch (...) {
    r = mi::neg_inf;
  }
  return caml_copy_double(r);
}

// owl: multinomial_rvs : int -> p:float array -> int array
CAMLprim value mi_multinomial_sample(value vn, value vp) {
  CAMLparam2(vn, vp);
  CAMLlocal1(out);
  const long n = Long_val(vn);
  std::vector<double> p;
  read_float_array(vp, p);
  if (n < 0 || !mi::simplex(p.data(), static_cast<int>(p.size())))
    caml_invalid_argument(
        "mi_multinomial_sample: require n >= 0 and a simplex of probabilities");
  std::vector<int> draw;
  try {
    draw = stan::math::multinomial_rng(to_eigen(p), static_cast<int>(n), mi::engine());
  } catch (...) {
    caml_failwith("mi_multinomial_sample: sampler failed");
  }
  out = caml_alloc(draw.size(), 0);
  for (size_t i = 0; i < draw.size(); ++i)
    Store_field(out, i, Val_long(draw[i]));
  CAMLreturn(out);
}

// owl: dirichlet_logpdf : float array -> alpha:float array -> float
CAMLprim value mi_dirichlet_lpdf(value vx, value valpha) {
  std::vector<double> x, alpha;
  read_float_array(vx, x);
  read_float_array(valpha, alpha);
  if (x.size() != alpha.size() ||
      !mi::all_positive(alpha.data(), static_cast<int>(alpha.size())))
    caml_invalid_argument(
        "mi_dirichlet_lpdf: alpha must be positive and match the length of x");
  if (!mi::simplex(x.data(), static_cast<int>(x.size())))
    return caml_copy_double(mi::neg_inf);  // out of support
  double r;
  try {
    r = stan::math::dirichlet_lpdf(to_eigen(x), to_eigen(alpha));
  } catch (...) {
    r = mi::neg_inf;
  }
  return caml_copy_double(r);
}

// owl: dirichlet_rvs : alpha:float array -> float array
CAMLprim value mi_dirichlet_sample(value valpha) {
  CAMLparam1(valpha);
  CAMLlocal1(out);
  std::vector<double> alpha;
  read_float_array(valpha, alpha);
  if (!mi::all_positive(alpha.data(), static_cast<int>(alpha.size())))
    caml_invalid_argument("mi_dirichlet_sample: alpha must be positive");
  Eigen::VectorXd draw;
  try {
    draw = stan::math::dirichlet_rng(to_eigen(alpha), mi::engine());
  } catch (...) {
    caml_failwith("mi_dirichlet_sample: sampler failed");
  }
  out = caml_alloc_float_array(draw.size());
  for (Eigen::Index i = 0; i < draw.size(); ++i)
    Store_double_field(out, i, draw[i]);
  CAMLreturn(out);
}

// owl reseeded four generators; there is one here.
CAMLprim value mi_set_seed(value vseed) {
  mi::engine().seed(static_cast<boost::random::mt19937::result_type>(Long_val(vseed)));
  return Val_unit;
}

// ---- bytecode entry points for the unboxed scalar externals ---------------
#define MI_BYTE1(name)                                     \
  CAMLprim value name##_byte(value a) {                    \
    return caml_copy_double(name(Double_val(a)));          \
  }
#define MI_BYTE2(name)                                     \
  CAMLprim value name##_byte(value a, value b) {           \
    return caml_copy_double(name(Double_val(a), Double_val(b))); \
  }
#define MI_BYTE3(name)                                                       \
  CAMLprim value name##_byte(value a, value b, value c) {                    \
    return caml_copy_double(                                                 \
        name(Double_val(a), Double_val(b), Double_val(c)));                  \
  }

MI_BYTE2(mi_chi2_lpdf)
MI_BYTE2(mi_chi2_cdf)
MI_BYTE3(mi_gamma_lpdf)
MI_BYTE3(mi_gamma_cdf)
MI_BYTE3(mi_beta_lpdf)
MI_BYTE3(mi_normal_lpdf)
MI_BYTE3(mi_lomax_lpdf)
MI_BYTE1(mi_chi2_sample)
MI_BYTE2(mi_gamma_sample)
MI_BYTE2(mi_beta_sample)
MI_BYTE2(mi_normal_sample)
MI_BYTE1(mi_exponential_sample)
MI_BYTE2(mi_uniform_sample)
MI_BYTE2(mi_lomax_sample)

}  // extern "C"
