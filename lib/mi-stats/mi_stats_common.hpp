// Shared conventions for every mi-stats translation unit.
#ifndef MI_STATS_COMMON_HPP
#define MI_STATS_COMMON_HPP

#include <cmath>
#include <limits>

namespace mi {

inline constexpr double neg_inf = -std::numeric_limits<double>::infinity();
inline constexpr double invalid = std::numeric_limits<double>::quiet_NaN();

// ---------------------------------------------------------------------------
// The error contract
// ---------------------------------------------------------------------------
// owl returned -inf for an out-of-support value; Stan Math instead raises
// std::domain_error -- and it raises the *same* exception for a genuinely
// invalid parameter (sigma <= 0, a non-simplex theta). Collapsing both to
// -inf would turn a caller bug into a zero-weight particle that SMC happily
// carries, so the two are kept apart:
//
//   out-of-support value  -> neg_inf   (matches owl; `observe` semantics hold)
//   invalid parameter     -> invalid   (NaN sentinel; mi_stats.ml raises)
//
// Parameters are therefore checked *here*, before the Stan call, and any
// exception that still escapes is treated as an out-of-support value. That
// makes this file's validation the thing under test, so each entry point in
// the test suite has a bad-parameter case next to its golden value.
//
// The sentinel is returned rather than raised so the scalar entry points can
// stay [@@unboxed] [@@noalloc] on the OCaml side: densities are evaluated
// once per particle per observe, and that is the hot path.
#define MI_SUPPORT(expr)                     \
  try {                                      \
    return (expr);                           \
  } catch (...) {                            \
    return mi::neg_inf;                      \
  }

// Parameter predicates, named for what they assert.
inline bool positive(double x) { return std::isfinite(x) && x > 0.0; }
inline bool nonneg(double x) { return std::isfinite(x) && x >= 0.0; }
inline bool probability(double p) { return std::isfinite(p) && p >= 0.0 && p <= 1.0; }
inline bool unit_open(double p) { return std::isfinite(p) && p > 0.0 && p < 1.0; }

inline bool simplex(const double *p, int n, double tol = 1e-8) {
  if (n <= 0) return false;
  double s = 0.0;
  for (int i = 0; i < n; ++i) {
    if (!std::isfinite(p[i]) || p[i] < 0.0) return false;
    s += p[i];
  }
  return std::fabs(s - 1.0) <= tol;
}

inline bool all_positive(const double *p, int n) {
  if (n <= 0) return false;
  for (int i = 0; i < n; ++i)
    if (!positive(p[i])) return false;
  return true;
}

}  // namespace mi

#endif
