// math-ext, plus the two quantiles Stan Math does not provide.
#include "mi_stats_common.hpp"

#include <stan/math/prim/fun/binomial_coefficient_log.hpp>
#include <stan/math/prim/fun/lgamma.hpp>

// Stan has no distribution quantile functions -- `prim/fun/quantile.hpp` is
// the sample quantile. Boost.Math does, and it is vendored anyway.
#include <boost/math/distributions/chi_squared.hpp>
#include <boost/math/distributions/gamma.hpp>

#include <caml/alloc.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

extern "C" {

// ---- math-ext -------------------------------------------------------------

double mi_lgamma(double x) {
  if (!std::isfinite(x)) return mi::invalid;
  MI_SUPPORT(stan::math::lgamma(x))
}

// owl: log_combination : int -> int -> float
CAMLprim value mi_log_combination(value vn, value vk) {
  const long n = Long_val(vn), k = Long_val(vk);
  if (n < 0 || k < 0 || k > n)
    caml_invalid_argument("mi_log_combination: require 0 <= k <= n");
  double r;
  try {
    r = stan::math::binomial_coefficient_log(static_cast<double>(n),
                                             static_cast<double>(k));
  } catch (...) {
    r = mi::neg_inf;
  }
  return caml_copy_double(r);
}

// ---- quantiles (chi2_ppf, gamma_ppf) --------------------------------------
// Note the parameterisations differ in opposite directions: Stan's gamma takes
// a *rate*, Boost's gamma_distribution takes a *scale*. owl used scale, so the
// density/cdf entry points convert and these do not.

// The boundaries are handled explicitly. Boost raises at p = 1 rather than
// returning an infinity, and MI_SUPPORT's -inf convention is meaningless for
// a quantile anyway -- the answer at the ends of [0, 1] is the end of the
// distribution's support. Both families here are supported on [0, inf), and
// owl agreed: gamma_ppf(0) = 0, gamma_ppf(1) = inf, likewise for chi2.
//
// dist-ext.mc:138 walks a linspace from 0 to 1 through gammaPpf and feeds the
// result straight back into gammaCdf, so getting these two points wrong
// poisons the whole discretised-support helper.
double mi_chi2_ppf(double p, double df) {
  if (!mi::probability(p) || !mi::positive(df)) return mi::invalid;
  if (p == 0.0) return 0.0;
  if (p == 1.0) return HUGE_VAL;
  MI_SUPPORT(boost::math::quantile(boost::math::chi_squared(df), p))
}

double mi_gamma_ppf(double p, double shape, double scale) {
  if (!mi::probability(p) || !mi::positive(shape) || !mi::positive(scale))
    return mi::invalid;
  if (p == 0.0) return 0.0;
  if (p == 1.0) return HUGE_VAL;
  MI_SUPPORT(boost::math::quantile(
      boost::math::gamma_distribution<double>(shape, scale), p))
}

// ---- bytecode entry points ------------------------------------------------
// Required by the two-name [@@unboxed] form: the first name is used when the
// program is compiled to bytecode, the second is called directly with
// unboxed doubles in native code. Miking only ever uses the native path.
CAMLprim value mi_lgamma_byte(value x) {
  return caml_copy_double(mi_lgamma(Double_val(x)));
}
CAMLprim value mi_chi2_ppf_byte(value p, value df) {
  return caml_copy_double(mi_chi2_ppf(Double_val(p), Double_val(df)));
}
CAMLprim value mi_gamma_ppf_byte(value p, value sh, value sc) {
  return caml_copy_double(
      mi_gamma_ppf(Double_val(p), Double_val(sh), Double_val(sc)));
}

}  // extern "C"
