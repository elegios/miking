include "map.mc"
include "ocaml/ast.mc"

-- Backed by lib/mi-stats. Neither Stan Math nor Eigen exposes a CBLAS API --
-- Stan links no BLAS at all and Eigen ships only the Fortran interface -- so
-- the five routines are written directly against Eigen::Map, which puts them
-- on the same kernels stan::math::multiply uses internally. copy, axpy and
-- scal are plain strided loops and touch no Eigen.
--
-- The MExpr API in cblas-ext.mc is unchanged, including the row/column-major
-- `layout` parameter and the `all a.` element polymorphism: mi-stats recovers
-- the element type from the Bigarray kind at run time and handles float32 and
-- float64 alike, which cblas-ext.mc's own utests require.
--
-- The enums are plain ints on the OCaml side, so the equality helpers are
-- integer comparison with no C support behind them.

let impl = lam arg : { expr : String, ty : use Ast in Type }.
  { expr = arg.expr, ty = arg.ty, libraries = ["mi-stats"], cLibraries = [] }

let cblasExtMap =
  use OCamlTypeAst in
  mapFromSeq cmpString [
    ("cblasRowMajor", [impl { expr = "Mi_stats.cblas_row_major", ty = otyopaque_ }]),
    ("cblasColMajor", [impl { expr = "Mi_stats.cblas_col_major", ty = otyopaque_ }]),
    ("cblasLayoutEq", [
      impl { expr = "(fun (x : int) (y : int) -> x = y)",
             ty = tyarrows_ [otyopaque_, otyopaque_, tybool_] }
    ]),
    ("cblasNoTrans", [impl { expr = "Mi_stats.cblas_no_trans", ty = otyopaque_ }]),
    ("cblasTrans", [impl { expr = "Mi_stats.cblas_trans", ty = otyopaque_ }]),
    -- Real doubles only, so this behaves as Trans. Its MExpr external is
    -- still commented out in cblas-ext.mc pending complex support.
    ("cblasConjTrans", [impl { expr = "Mi_stats.cblas_conj_trans", ty = otyopaque_ }]),
    ("cblasTransEq", [
      impl { expr = "(fun (x : int) (y : int) -> x = y)",
             ty = tyarrows_ [otyopaque_, otyopaque_, tybool_] }
    ]),
    ("cblasUpperTriag", [impl { expr = "Mi_stats.cblas_upper", ty = otyopaque_ }]),
    ("cblasLowerTriag", [impl { expr = "Mi_stats.cblas_lower", ty = otyopaque_ }]),
    ("cblasTriagEq", [
      impl { expr = "(fun (x : int) (y : int) -> x = y)",
             ty = tyarrows_ [otyopaque_, otyopaque_, tybool_] }
    ]),
    ("cblasNonUnitDiag", [impl { expr = "Mi_stats.cblas_non_unit", ty = otyopaque_ }]),
    ("cblasUnitDiag", [impl { expr = "Mi_stats.cblas_unit", ty = otyopaque_ }]),
    ("cblasDiagEq", [
      impl { expr = "(fun (x : int) (y : int) -> x = y)",
             ty = tyarrows_ [otyopaque_, otyopaque_, tybool_] }
    ]),
    ("cblasLeftSide", [impl { expr = "Mi_stats.cblas_left", ty = otyopaque_ }]),
    ("cblasRightSide", [impl { expr = "Mi_stats.cblas_right", ty = otyopaque_ }]),
    ("cblasSideEq", [
      impl { expr = "(fun (x : int) (y : int) -> x = y)",
             ty = tyarrows_ [otyopaque_, otyopaque_, tybool_] }
    ]),

    ("externalCblasAxpy", [
      impl { expr = "Mi_stats.cblas_axpy",
             ty = tyall_ "a" (tyarrows_ [
               tyint_, tyvar_ "a", otyopaque_, tyint_, otyopaque_, tyint_,
               otyunit_]) }
    ]),
    ("externalCblasCopy", [
      impl { expr = "Mi_stats.cblas_copy",
             ty = tyarrows_ [
               tyint_, otyopaque_, tyint_, otyopaque_, tyint_, otyunit_] }
    ]),
    ("externalCblasScal", [
      impl { expr = "Mi_stats.cblas_scal",
             ty = tyall_ "a" (tyarrows_ [
               tyint_, tyvar_ "a", otyopaque_, tyint_, otyunit_]) }
    ]),
    ("externalCblasGemv", [
      impl { expr = "Mi_stats.cblas_gemv",
             ty = tyall_ "a" (tyarrows_ [
               otyopaque_, otyopaque_,
               tyint_, tyint_,
               tyvar_ "a",
               otyopaque_, tyint_,
               otyopaque_, tyint_,
               tyvar_ "a",
               otyopaque_, tyint_,
               otyunit_]) }
    ]),
    ("externalCblasGemm", [
      impl { expr = "Mi_stats.cblas_gemm",
             ty = tyall_ "a" (tyarrows_ [
               otyopaque_, otyopaque_, otyopaque_,
               tyint_, tyint_, tyint_,
               tyvar_ "a",
               otyopaque_, tyint_,
               otyopaque_, tyint_,
               tyvar_ "a",
               otyopaque_, tyint_,
               otyunit_]) }
    ])
  ]
