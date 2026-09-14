// cblas-ext: the five BLAS routines Miking exposes, plus the enum surface.
//
// Neither Stan Math nor Eigen offers a CBLAS API. Stan links no BLAS at all
// (no cblas_ symbols, no EIGEN_USE_BLAS) and Eigen ships only the *Fortran*
// interface in its blas/ directory. So these are written directly, which is
// what keeps cblas-ext.mc's MExpr API -- including its row/column-major
// `layout` parameter -- byte-identical across the migration.
//
// These stay generic over the element type. cblas-ext.mc declares them
// `all a. ... ExtArr a ...` and its own utests run every routine over both
// extArrKindFloat32 and extArrKindFloat64, so a float64-only shim would fail
// them. The element type is recovered from the Bigarray's kind at run time
// and the templated body is instantiated for each; `alpha` and `beta` always
// arrive as OCaml floats, i.e. C doubles, whatever the array holds.
//
// The enums are plain ints on the OCaml side (see mi_stats.ml), so the
// equality helpers cblas-ext.mc declares become integer comparison and need
// no C support at all.
#include "mi_stats_common.hpp"

#include <Eigen/Dense>

#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

namespace {

// Mirrors the CblasRowMajor / CblasColMajor and CblasNoTrans / CblasTrans /
// CblasConjTrans orders that mi_stats.ml exposes.
enum Layout { RowMajor = 0, ColMajor = 1 };
enum Trans { NoTrans = 0 };

inline void need(bool ok, const char *msg) {
  if (!ok) caml_invalid_argument(msg);
}

inline int kind_of(value v) {
  return Caml_ba_array_val(v)->flags & CAML_BA_KIND_MASK;
}

// Every array argument of one call must hold the same element type.
inline int common_kind(const value *vs, int n, const char *who) {
  const int k = kind_of(vs[0]);
  for (int i = 1; i < n; ++i)
    need(kind_of(vs[i]) == k, "mi_stats: mixed element kinds in one BLAS call");
  need(k == CAML_BA_FLOAT32 || k == CAML_BA_FLOAT64,
       who);
  return k;
}

template <typename T>
inline T *dat(value v) {
  return static_cast<T *>(Caml_ba_data_val(v));
}

// Dispatch a templated body on float32 / float64.
#define MI_ON_KIND(k, body)                    \
  do {                                         \
    if ((k) == CAML_BA_FLOAT64) {              \
      body(double);                            \
    } else {                                   \
      body(float);                             \
    }                                          \
  } while (0)

// Eigen's Map is column-major by default: the outer stride advances a column,
// the inner stride advances a row. Row-major storage swaps the two roles, so
// one stride pair expresses both CBLAS layouts.
inline Eigen::Stride<Eigen::Dynamic, Eigen::Dynamic> strides(int layout, long ld) {
  return layout == RowMajor
             ? Eigen::Stride<Eigen::Dynamic, Eigen::Dynamic>(1, ld)
             : Eigen::Stride<Eigen::Dynamic, Eigen::Dynamic>(ld, 1);
}

template <typename T>
using DynMat = Eigen::Matrix<T, Eigen::Dynamic, Eigen::Dynamic>;
template <typename T>
using DynVec = Eigen::Matrix<T, Eigen::Dynamic, 1>;

}  // namespace

extern "C" {

// ---- level 1: strided vector loops (no Eigen needed) --------------------

// y := x
CAMLprim value mi_cblas_copy(value vn, value vx, value vincx, value vy,
                             value vincy) {
  const long n = Long_val(vn), ix = Long_val(vincx), iy = Long_val(vincy);
  need(n >= 0, "mi_cblas_copy: n must be non-negative");
  const value arrs[2] = {vx, vy};
  const int k = common_kind(arrs, 2, "mi_cblas_copy: expected a float array");
#define MI_COPY_BODY(T)                                       \
  {                                                           \
    const T *x = dat<T>(vx);                                  \
    T *y = dat<T>(vy);                                        \
    for (long i = 0; i < n; ++i) y[i * iy] = x[i * ix];       \
  }
  MI_ON_KIND(k, MI_COPY_BODY);
#undef MI_COPY_BODY
  return Val_unit;
}
CAMLprim value mi_cblas_copy_byte(value *a, int n) {
  (void)n;
  return mi_cblas_copy(a[0], a[1], a[2], a[3], a[4]);
}

// y := alpha * x + y
CAMLprim value mi_cblas_axpy(value vn, value valpha, value vx, value vincx,
                             value vy, value vincy) {
  const long n = Long_val(vn), ix = Long_val(vincx), iy = Long_val(vincy);
  need(n >= 0, "mi_cblas_axpy: n must be non-negative");
  const double alpha = Double_val(valpha);
  const value arrs[2] = {vx, vy};
  const int k = common_kind(arrs, 2, "mi_cblas_axpy: expected a float array");
#define MI_AXPY_BODY(T)                                                 \
  {                                                                     \
    const T *x = dat<T>(vx);                                            \
    T *y = dat<T>(vy);                                                  \
    const T a = static_cast<T>(alpha);                                  \
    for (long i = 0; i < n; ++i) y[i * iy] += a * x[i * ix];            \
  }
  MI_ON_KIND(k, MI_AXPY_BODY);
#undef MI_AXPY_BODY
  return Val_unit;
}
CAMLprim value mi_cblas_axpy_byte(value *a, int n) {
  (void)n;
  return mi_cblas_axpy(a[0], a[1], a[2], a[3], a[4], a[5]);
}

// x := alpha * x
CAMLprim value mi_cblas_scal(value vn, value valpha, value vx, value vincx) {
  const long n = Long_val(vn), ix = Long_val(vincx);
  need(n >= 0, "mi_cblas_scal: n must be non-negative");
  const double alpha = Double_val(valpha);
  const value arrs[1] = {vx};
  const int k = common_kind(arrs, 1, "mi_cblas_scal: expected a float array");
#define MI_SCAL_BODY(T)                                        \
  {                                                            \
    T *x = dat<T>(vx);                                         \
    const T a = static_cast<T>(alpha);                         \
    for (long i = 0; i < n; ++i) x[i * ix] *= a;               \
  }
  MI_ON_KIND(k, MI_SCAL_BODY);
#undef MI_SCAL_BODY
  return Val_unit;
}

// ---- level 2 and 3: via Eigen -------------------------------------------
// Wrapping Eigen::Map puts these on the same kernels stan::math::multiply
// uses internally.

// y := alpha * op(A) * x + beta * y, where A is the m x n stored matrix.
CAMLprim value mi_cblas_gemv(value *a, int argn) {
  need(argn == 12, "mi_cblas_gemv: expected 12 arguments");
  const int layout = Int_val(a[0]), trans = Int_val(a[1]);
  const long m = Long_val(a[2]), n = Long_val(a[3]);
  const double alpha = Double_val(a[4]);
  const long lda = Long_val(a[6]), incx = Long_val(a[8]);
  const double beta = Double_val(a[9]);
  const long incy = Long_val(a[11]);
  need(m >= 0 && n >= 0, "mi_cblas_gemv: negative dimension");
  const bool t = (trans != NoTrans);
  const long xlen = t ? m : n, ylen = t ? n : m;
  const value arrs[3] = {a[5], a[7], a[10]};
  const int k = common_kind(arrs, 3, "mi_cblas_gemv: expected a float array");
#define MI_GEMV_BODY(T)                                                       \
  {                                                                           \
    Eigen::Map<const DynMat<T>, 0,                                            \
               Eigen::Stride<Eigen::Dynamic, Eigen::Dynamic>>                 \
        A(dat<T>(a[5]), m, n, strides(layout, lda));                          \
    Eigen::Map<const DynVec<T>, 0, Eigen::InnerStride<Eigen::Dynamic>> x(     \
        dat<T>(a[7]), xlen, Eigen::InnerStride<Eigen::Dynamic>(incx));        \
    Eigen::Map<DynVec<T>, 0, Eigen::InnerStride<Eigen::Dynamic>> y(           \
        dat<T>(a[10]), ylen, Eigen::InnerStride<Eigen::Dynamic>(incy));       \
    const T al = static_cast<T>(alpha), be = static_cast<T>(beta);            \
    if (t)                                                                    \
      y = al * (A.transpose() * x) + be * y;                                  \
    else                                                                      \
      y = al * (A * x) + be * y;                                              \
  }
  MI_ON_KIND(k, MI_GEMV_BODY);
#undef MI_GEMV_BODY
  return Val_unit;
}
CAMLprim value mi_cblas_gemv_native(value l, value tr, value m, value n,
                                    value al, value A, value lda, value x,
                                    value incx, value be, value y,
                                    value incy) {
  value a[12] = {l, tr, m, n, al, A, lda, x, incx, be, y, incy};
  return mi_cblas_gemv(a, 12);
}

// C := alpha * op(A) * op(B) + beta * C
CAMLprim value mi_cblas_gemm(value *a, int argn) {
  need(argn == 14, "mi_cblas_gemm: expected 14 arguments");
  const int layout = Int_val(a[0]), ta = Int_val(a[1]), tb = Int_val(a[2]);
  const long m = Long_val(a[3]), n = Long_val(a[4]), kk = Long_val(a[5]);
  const double alpha = Double_val(a[6]);
  const long lda = Long_val(a[8]), ldb = Long_val(a[10]);
  const double beta = Double_val(a[11]);
  const long ldc = Long_val(a[13]);
  need(m >= 0 && n >= 0 && kk >= 0, "mi_cblas_gemm: negative dimension");
  // op(A) is m x k and op(B) is k x n, so the *stored* shapes depend on the
  // transposition flags.
  const bool tA = (ta != NoTrans), tB = (tb != NoTrans);
  const value arrs[3] = {a[7], a[9], a[12]};
  const int k = common_kind(arrs, 3, "mi_cblas_gemm: expected a float array");
#define MI_GEMM_BODY(T)                                                       \
  {                                                                           \
    using SMap = Eigen::Map<const DynMat<T>, 0,                               \
                            Eigen::Stride<Eigen::Dynamic, Eigen::Dynamic>>;   \
    SMap A(dat<T>(a[7]), tA ? kk : m, tA ? m : kk, strides(layout, lda));     \
    SMap B(dat<T>(a[9]), tB ? n : kk, tB ? kk : n, strides(layout, ldb));     \
    Eigen::Map<DynMat<T>, 0, Eigen::Stride<Eigen::Dynamic, Eigen::Dynamic>>   \
        C(dat<T>(a[12]), m, n, strides(layout, ldc));                         \
    const T al = static_cast<T>(alpha), be = static_cast<T>(beta);            \
    if (tA && tB)                                                             \
      C = al * (A.transpose() * B.transpose()) + be * C;                      \
    else if (tA)                                                              \
      C = al * (A.transpose() * B) + be * C;                                  \
    else if (tB)                                                              \
      C = al * (A * B.transpose()) + be * C;                                  \
    else                                                                      \
      C = al * (A * B) + be * C;                                              \
  }
  MI_ON_KIND(k, MI_GEMM_BODY);
#undef MI_GEMM_BODY
  return Val_unit;
}
CAMLprim value mi_cblas_gemm_native(value l, value ta, value tb, value m,
                                    value n, value k, value al, value A,
                                    value lda, value B, value ldb, value be,
                                    value C, value ldc) {
  value a[14] = {l, ta, tb, m, n, k, al, A, lda, B, ldb, be, C, ldc};
  return mi_cblas_gemm(a, 14);
}

}  // extern "C"
