// mat-ext and matrix-ext.
//
// Two representations, both C-layout float64 Bigarrays, mapped in place with
// Eigen::Map so nothing is copied:
//   * mat-ext    passes a flat Array1 plus explicit (m, n) and writes into a
//                caller-provided output buffer -- owl's in-place `~out:` forms.
//   * matrix-ext passes a 2-D Genarray and returns a freshly allocated one.
//
// expm comes from Stan (matrix_exp -> matrix_exp_pade), not from Eigen's
// unsupported/MatrixFunctions, which is therefore never vendored.
#include "mi_stats_common.hpp"

#include <stan/math/prim/fun/matrix_exp.hpp>

#include <Eigen/Dense>

#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

namespace {

// matrix-ext passes Tensor[Float], i.e. a float64 Genarray, so that half is
// double-only. mat-ext passes ExtArr Float, whose backing kind may be
// float32 or float64 -- and mat-ext.mc's utests run every routine over both
// (`test extArrKindFloat32`) -- so that half dispatches on the kind.
template <typename T>
using RowMajorT = Eigen::Matrix<T, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor>;

using RowMajor = RowMajorT<double>;
using MapRW = Eigen::Map<RowMajor>;
using MapRO = Eigen::Map<const RowMajor>;

inline double *data(value v) { return static_cast<double *>(Caml_ba_data_val(v)); }

template <typename T>
inline T *dat(value v) { return static_cast<T *>(Caml_ba_data_val(v)); }

inline int kind_of(value v) {
  return Caml_ba_array_val(v)->flags & CAML_BA_KIND_MASK;
}

inline int elem_kind(value a, value b) {
  const int k = kind_of(a);
  if (kind_of(b) != k)
    caml_invalid_argument("mi_stats: mixed element kinds in one call");
  if (k != CAML_BA_FLOAT32 && k != CAML_BA_FLOAT64)
    caml_invalid_argument("mi_stats: expected a float array");
  return k;
}

#define MI_ON_KIND(k, body)       \
  do {                            \
    if ((k) == CAML_BA_FLOAT64) { \
      body(double);               \
    } else {                      \
      body(float);                \
    }                             \
  } while (0)

// A 2-D C-layout Genarray, as matrix-ext declares.
inline MapRO map2(value v) {
  const caml_ba_array *b = Caml_ba_array_val(v);
  if (b->num_dims != 2) caml_invalid_argument("mi_stats: expected a 2-D matrix");
  return MapRO(data(v), b->dim[0], b->dim[1]);
}

inline value alloc2(intnat rows, intnat cols) {
  return caml_ba_alloc_dims(CAML_BA_FLOAT64 | CAML_BA_C_LAYOUT | CAML_BA_MANAGED,
                            2, NULL, rows, cols);
}

inline void check_dims(int m, int n) {
  if (m < 0 || n < 0) caml_invalid_argument("mi_stats: negative matrix dimension");
}

}  // namespace

extern "C" {

// ===========================================================================
// mat-ext -- in place, flat Array1 plus (m, n)
// ===========================================================================

// b (n x m) := transpose of a (m x n)
CAMLprim value mi_mat_transpose(value vm, value vn, value va, value vb) {
  const int m = Int_val(vm), n = Int_val(vn);
  check_dims(m, n);
  const int k = elem_kind(va, vb);
#define MI_T_BODY(T)                                                        \
  Eigen::Map<RowMajorT<T>>(dat<T>(vb), n, m) =                              \
      Eigen::Map<const RowMajorT<T>>(dat<T>(va), m, n).transpose();
  MI_ON_KIND(k, MI_T_BODY);
#undef MI_T_BODY
  return Val_unit;
}

#define MI_ELEMWISE_UNOP(name, op)                                          \
  CAMLprim value name(value vm, value vn, value va, value vb) {             \
    const int m = Int_val(vm), n = Int_val(vn);                             \
    check_dims(m, n);                                                       \
    const int k = elem_kind(va, vb);                                        \
    _Pragma("GCC diagnostic push")                                          \
    _Pragma("GCC diagnostic ignored \"-Wunused-variable\"")                 \
    if (k == CAML_BA_FLOAT64) {                                             \
      Eigen::Map<const RowMajorT<double>> a(dat<double>(va), m, n);          \
      Eigen::Map<RowMajorT<double>>(dat<double>(vb), m, n) = op;            \
    } else {                                                                \
      Eigen::Map<const RowMajorT<float>> a(dat<float>(va), m, n);            \
      Eigen::Map<RowMajorT<float>>(dat<float>(vb), m, n) = op;              \
    }                                                                       \
    _Pragma("GCC diagnostic pop")                                           \
    return Val_unit;                                                        \
  }

MI_ELEMWISE_UNOP(mi_mat_elem_exp, a.array().exp())
MI_ELEMWISE_UNOP(mi_mat_elem_log, a.array().log())

// c := a .* b, all m x n
CAMLprim value mi_mat_elem_mul(value vm, value vn, value va, value vb, value vc) {
  const int m = Int_val(vm), n = Int_val(vn);
  check_dims(m, n);
  elem_kind(va, vb);
  const int k = elem_kind(vb, vc);
#define MI_EM_BODY(T)                                                       \
  {                                                                         \
    Eigen::Map<const RowMajorT<T>> a(dat<T>(va), m, n), b(dat<T>(vb), m, n); \
    Eigen::Map<RowMajorT<T>>(dat<T>(vc), m, n) = a.array() * b.array();     \
  }
  MI_ON_KIND(k, MI_EM_BODY);
#undef MI_EM_BODY
  return Val_unit;
}
CAMLprim value mi_mat_elem_mul_byte(value *argv, int argn) {
  (void)argn;
  return mi_mat_elem_mul(argv[0], argv[1], argv[2], argv[3], argv[4]);
}

// Returns a fresh flat Array1 of length m*n holding expm(a).
CAMLprim value mi_mat_exp(value vm, value vn, value va) {
  CAMLparam3(vm, vn, va);
  CAMLlocal1(out);
  const int m = Int_val(vm), n = Int_val(vn);
  if (m != n) caml_invalid_argument("mi_mat_exp: matrix must be square");
  check_dims(m, n);
  // Computed in double regardless of the input kind -- expm is
  // scaling-and-squaring, and doing it in single precision would lose far
  // more than the storage saves. The result is written back in the input's
  // kind so the caller's representation is preserved.
  const int k = kind_of(va);
  if (k != CAML_BA_FLOAT32 && k != CAML_BA_FLOAT64)
    caml_invalid_argument("mi_mat_exp: expected a float array");
  Eigen::MatrixXd in(m, n);
  if (k == CAML_BA_FLOAT64)
    in = Eigen::Map<const RowMajorT<double>>(dat<double>(va), m, n);
  else
    in = Eigen::Map<const RowMajorT<float>>(dat<float>(va), m, n).cast<double>();
  Eigen::MatrixXd r;
  try {
    r = stan::math::matrix_exp(in);
  } catch (...) {
    caml_failwith("mi_mat_exp: matrix exponential failed");
  }
  const intnat len = static_cast<intnat>(m) * n;
  out = caml_ba_alloc_dims(
      (k == CAML_BA_FLOAT64 ? CAML_BA_FLOAT64 : CAML_BA_FLOAT32) |
          CAML_BA_C_LAYOUT | CAML_BA_MANAGED,
      1, NULL, len);
  if (k == CAML_BA_FLOAT64)
    Eigen::Map<RowMajorT<double>>(dat<double>(out), m, n) = r;
  else
    Eigen::Map<RowMajorT<float>>(dat<float>(out), m, n) = r.cast<float>();
  CAMLreturn(out);
}

// ===========================================================================
// matrix-ext -- value-returning, 2-D Genarray
// ===========================================================================

CAMLprim value mi_matrix_exp(value va) {
  CAMLparam1(va);
  CAMLlocal1(out);
  MapRO a = map2(va);
  if (a.rows() != a.cols())
    caml_invalid_argument("mi_matrix_exp: matrix must be square");
  Eigen::MatrixXd r;
  try {
    r = stan::math::matrix_exp(Eigen::MatrixXd(a));
  } catch (...) {
    caml_failwith("mi_matrix_exp: matrix exponential failed");
  }
  out = alloc2(r.rows(), r.cols());
  MapRW(data(out), r.rows(), r.cols()) = r;
  CAMLreturn(out);
}

CAMLprim value mi_matrix_transpose(value va) {
  CAMLparam1(va);
  CAMLlocal1(out);
  MapRO a = map2(va);
  out = alloc2(a.cols(), a.rows());
  MapRW(data(out), a.cols(), a.rows()) = a.transpose();
  CAMLreturn(out);
}

// owl's ( $* ) is float -> mat -> mat, so the scalar comes first.
CAMLprim value mi_matrix_mul_float(value vs, value va) {
  CAMLparam2(vs, va);
  CAMLlocal1(out);
  MapRO a = map2(va);
  out = alloc2(a.rows(), a.cols());
  MapRW(data(out), a.rows(), a.cols()) = Double_val(vs) * a;
  CAMLreturn(out);
}

// ( *@ ) -- true matrix product
CAMLprim value mi_matrix_mul(value va, value vb) {
  CAMLparam2(va, vb);
  CAMLlocal1(out);
  MapRO a = map2(va), b = map2(vb);
  if (a.cols() != b.rows())
    caml_invalid_argument("mi_matrix_mul: inner dimensions disagree");
  out = alloc2(a.rows(), b.cols());
  MapRW(data(out), a.rows(), b.cols()) = a * b;
  CAMLreturn(out);
}

#define MI_MATRIX_BINOP(name, op, what)                                    \
  CAMLprim value name(value va, value vb) {                                \
    CAMLparam2(va, vb);                                                    \
    CAMLlocal1(out);                                                       \
    MapRO a = map2(va), b = map2(vb);                                      \
    if (a.rows() != b.rows() || a.cols() != b.cols())                      \
      caml_invalid_argument("mi_stats: " what ": shapes disagree");         \
    out = alloc2(a.rows(), a.cols());                                      \
    MapRW(data(out), a.rows(), a.cols()) = op;                             \
    CAMLreturn(out);                                                       \
  }

MI_MATRIX_BINOP(mi_matrix_elem_mul, a.array() * b.array(), "elementwise multiply")
MI_MATRIX_BINOP(mi_matrix_elem_add, a + b, "elementwise add")

}  // extern "C"
