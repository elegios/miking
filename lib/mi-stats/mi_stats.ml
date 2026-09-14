(* Miking's numerics support library, backing the externals that used to be
   bound to owl. See lib/README.md for what is vendored and why.

   Calling convention. The scalar entry points are declared with the two-name
   [@@unboxed] [@@noalloc] form, so in native code OCaml passes and returns
   raw doubles with no boxing. That matters: a density is evaluated once per
   particle per [observe], and it is the hot path in every SMC run. The first
   C name is a bytecode wrapper that the [@@unboxed] form requires; Miking
   only ever takes the native path, since src/stdlib/ocaml/compile.mc invokes
   [ocamlfind ocamlopt].

   Error contract. [@@noalloc] forbids raising from C, so the C layer signals
   through the return value instead and the wrappers here turn that into an
   exception:

     out-of-support value  ->  neg_infinity, returned as-is (matches owl, and
                               keeps CorePPL's [observe] semantics unchanged)
     invalid parameter     ->  nan from C, raised here as [Invalid_argument]

   Collapsing both into neg_infinity would let a caller bug -- a negative
   sigma, a non-simplex theta -- become a zero-weight particle that SMC
   carries along silently. Entry points taking ints or arrays are ordinary
   [value] stubs and raise from C directly. *)

let[@inline] chk name (x : float) =
  if Float.is_nan x then
    invalid_arg (name ^ ": invalid distribution parameter")
  else x

(* ------------------------------------------------------------------ *)
(* math-ext                                                            *)
(* ------------------------------------------------------------------ *)

external raw_log_gamma : float -> float
  = "mi_lgamma_byte" "mi_lgamma" [@@unboxed] [@@noalloc]

let log_gamma x = chk "log_gamma" (raw_log_gamma x)

(* log_combination n k = log (n choose k) *)
external log_combination : int -> int -> float = "mi_log_combination"

(* ------------------------------------------------------------------ *)
(* Quantiles. Stan Math has no distribution quantile functions, so     *)
(* these two come from Boost.Math, which is vendored regardless.       *)
(* ------------------------------------------------------------------ *)

external raw_chi2_ppf : float -> float -> float
  = "mi_chi2_ppf_byte" "mi_chi2_ppf" [@@unboxed] [@@noalloc]

external raw_gamma_ppf : float -> float -> float -> float
  = "mi_gamma_ppf_byte" "mi_gamma_ppf" [@@unboxed] [@@noalloc]

let chi2_ppf p df = chk "chi2_ppf" (raw_chi2_ppf p df)

(* [scale], not rate -- matching owl. Boost's gamma_distribution also takes a
   scale, so unlike the density and CDF below this one does not convert. *)
let gamma_ppf p shape scale = chk "gamma_ppf" (raw_gamma_ppf p shape scale)

(* ------------------------------------------------------------------ *)
(* Densities and CDFs                                                  *)
(* ------------------------------------------------------------------ *)

external raw_chi2_lpdf : float -> float -> float
  = "mi_chi2_lpdf_byte" "mi_chi2_lpdf" [@@unboxed] [@@noalloc]
external raw_chi2_cdf : float -> float -> float
  = "mi_chi2_cdf_byte" "mi_chi2_cdf" [@@unboxed] [@@noalloc]
external raw_gamma_lpdf : float -> float -> float -> float
  = "mi_gamma_lpdf_byte" "mi_gamma_lpdf" [@@unboxed] [@@noalloc]
external raw_gamma_cdf : float -> float -> float -> float
  = "mi_gamma_cdf_byte" "mi_gamma_cdf" [@@unboxed] [@@noalloc]
external raw_beta_lpdf : float -> float -> float -> float
  = "mi_beta_lpdf_byte" "mi_beta_lpdf" [@@unboxed] [@@noalloc]
external raw_normal_lpdf : float -> float -> float -> float
  = "mi_normal_lpdf_byte" "mi_normal_lpdf" [@@unboxed] [@@noalloc]
external raw_lomax_lpdf : float -> float -> float -> float
  = "mi_lomax_lpdf_byte" "mi_lomax_lpdf" [@@unboxed] [@@noalloc]

let chi2_lpdf x df = chk "chi2_lpdf" (raw_chi2_lpdf x df)
let chi2_cdf x df = chk "chi2_cdf" (raw_chi2_cdf x df)

(* [scale], not rate. Converted to Stan's rate inside the C layer. *)
let gamma_lpdf x shape scale = chk "gamma_lpdf" (raw_gamma_lpdf x shape scale)
let gamma_cdf x shape scale = chk "gamma_cdf" (raw_gamma_cdf x shape scale)
let beta_lpdf x a b = chk "beta_lpdf" (raw_beta_lpdf x a b)
let normal_lpdf x mu sigma = chk "normal_lpdf" (raw_normal_lpdf x mu sigma)

(* Lomax, i.e. Pareto Type II with mu = 0. Provided for completeness and
   currently unused: dist-ext.mc computes this density in MExpr, because owl's
   own lomax_logpdf implements Pareto Type I and so disagreed with owl's
   lomax_rvs. This one agrees with both the MExpr version and mi_lomax_sample. *)
let lomax_lpdf x shape scale = chk "lomax_lpdf" (raw_lomax_lpdf x shape scale)

(* owl: binomial_logpdf : int -> p:float -> n:int -> float *)
external binomial_lpmf : int -> float -> int -> float = "mi_binomial_lpmf"

external multinomial_lpmf : int array -> float array -> float
  = "mi_multinomial_lpmf"

external dirichlet_lpdf : float array -> float array -> float
  = "mi_dirichlet_lpdf"

(* ------------------------------------------------------------------ *)
(* Samplers. All draw from the one generator [set_seed] reseeds.       *)
(* ------------------------------------------------------------------ *)

external raw_chi2_sample : float -> float
  = "mi_chi2_sample_byte" "mi_chi2_sample" [@@unboxed] [@@noalloc]
external raw_gamma_sample : float -> float -> float
  = "mi_gamma_sample_byte" "mi_gamma_sample" [@@unboxed] [@@noalloc]
external raw_beta_sample : float -> float -> float
  = "mi_beta_sample_byte" "mi_beta_sample" [@@unboxed] [@@noalloc]
external raw_normal_sample : float -> float -> float
  = "mi_normal_sample_byte" "mi_normal_sample" [@@unboxed] [@@noalloc]
external raw_exponential_sample : float -> float
  = "mi_exponential_sample_byte" "mi_exponential_sample" [@@unboxed] [@@noalloc]
external raw_uniform_sample : float -> float -> float
  = "mi_uniform_sample_byte" "mi_uniform_sample" [@@unboxed] [@@noalloc]
external raw_lomax_sample : float -> float -> float
  = "mi_lomax_sample_byte" "mi_lomax_sample" [@@unboxed] [@@noalloc]

let chi2_sample df = chk "chi2_sample" (raw_chi2_sample df)
let gamma_sample shape scale = chk "gamma_sample" (raw_gamma_sample shape scale)
let beta_sample a b = chk "beta_sample" (raw_beta_sample a b)
let normal_sample mu sigma = chk "normal_sample" (raw_normal_sample mu sigma)

(* rate, as in owl's [~lambda] *)
let exponential_sample lambda =
  chk "exponential_sample" (raw_exponential_sample lambda)

let uniform_sample a b = chk "uniform_sample" (raw_uniform_sample a b)
let lomax_sample shape scale = chk "lomax_sample" (raw_lomax_sample shape scale)

external binomial_sample : float -> int -> int = "mi_binomial_sample"

(* inclusive on both ends, as owl's uniform_int_rvs was *)
external uniform_int_sample : int -> int -> int = "mi_uniform_int_sample"

(* 0-based, as owl's categorical_rvs was; Stan's own is 1-based *)
external categorical_sample : float array -> int = "mi_categorical_sample"

external multinomial_sample : int -> float array -> int array
  = "mi_multinomial_sample"

external dirichlet_sample : float array -> float array = "mi_dirichlet_sample"

(* ------------------------------------------------------------------ *)
(* Seeding                                                             *)
(* ------------------------------------------------------------------ *)

(* Reseeds the single generator every sampler above draws from. owl's
   externalSetSeed reached into four separate generators; callers had no way
   to tell which one a given distribution used. *)
external set_seed : int -> unit = "mi_set_seed"

(* ------------------------------------------------------------------ *)
(* mat-ext: flat float64 Array1 plus explicit (m, n), written in place *)
(* ------------------------------------------------------------------ *)

(* ExtArr Float may be backed by float32 or float64; both halves of mat-ext
   and all of cblas-ext are generic over the kind, as owl's were. *)
type 'k arr = (float, 'k, Bigarray.c_layout) Bigarray.Array1.t
type mat = (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Genarray.t

(* b (n x m) := transpose of a (m x n) *)
external mat_transpose : int -> int -> 'k arr -> 'k arr -> unit = "mi_mat_transpose"
external mat_elem_exp : int -> int -> 'k arr -> 'k arr -> unit = "mi_mat_elem_exp"
external mat_elem_log : int -> int -> 'k arr -> 'k arr -> unit = "mi_mat_elem_log"

(* c := a .* b. Six-argument externals need the bytecode/native name pair. *)
external mat_elem_mul : int -> int -> 'k arr -> 'k arr -> 'k arr -> unit
  = "mi_mat_elem_mul_byte" "mi_mat_elem_mul"

(* Fresh flat array of length m*n holding expm a. From Stan's matrix_exp. *)
external mat_exp : int -> int -> 'k arr -> 'k arr = "mi_mat_exp"

(* ------------------------------------------------------------------ *)
(* matrix-ext: 2-D C-layout Genarray, value-returning                  *)
(* ------------------------------------------------------------------ *)

external matrix_exp : mat -> mat = "mi_matrix_exp"
external matrix_transpose : mat -> mat = "mi_matrix_transpose"

(* owl's ( $* ): the scalar comes first *)
external matrix_mul_float : float -> mat -> mat = "mi_matrix_mul_float"

external matrix_mul : mat -> mat -> mat = "mi_matrix_mul"       (* ( *@ ) *)
external matrix_elem_mul : mat -> mat -> mat = "mi_matrix_elem_mul"
external matrix_elem_add : mat -> mat -> mat = "mi_matrix_elem_add"

(* ------------------------------------------------------------------ *)
(* cblas-ext                                                           *)
(* ------------------------------------------------------------------ *)

(* The enum surface. These are plain ints rather than an abstract type so the
   equality helpers cblas-ext.mc declares (cblasLayoutEq and friends) are just
   integer comparison, with no C support needed. Values match the order the
   C layer decodes -- see mi_stats_blas.cpp. *)
let cblas_row_major = 0
let cblas_col_major = 1
let cblas_no_trans = 0
let cblas_trans = 1

(* Real doubles only, so ConjTrans behaves as Trans. Retained because
   cblas-ext.mc still names it, with its MExpr external commented out
   pending complex support. *)
let cblas_conj_trans = 2

let cblas_upper = 0
let cblas_lower = 1
let cblas_non_unit = 0
let cblas_unit = 1
let cblas_left = 0
let cblas_right = 1

(* y := x *)
external cblas_copy : int -> 'k arr -> int -> 'k arr -> int -> unit
  = "mi_cblas_copy_byte" "mi_cblas_copy"

(* y := alpha * x + y *)
external cblas_axpy : int -> float -> 'k arr -> int -> 'k arr -> int -> unit
  = "mi_cblas_axpy_byte" "mi_cblas_axpy"

(* x := alpha * x *)
external cblas_scal : int -> float -> 'k arr -> int -> unit = "mi_cblas_scal"

(* y := alpha * op(A) * x + beta * y *)
external cblas_gemv :
  int -> int -> int -> int -> float -> 'k arr -> int -> 'k arr -> int -> float ->
  'k arr -> int -> unit
  = "mi_cblas_gemv" "mi_cblas_gemv_native"

(* C := alpha * op(A) * op(B) + beta * C *)
external cblas_gemm :
  int -> int -> int -> int -> int -> int -> float -> 'k arr -> int -> 'k arr ->
  int -> float -> 'k arr -> int -> unit
  = "mi_cblas_gemm" "mi_cblas_gemm_native"
