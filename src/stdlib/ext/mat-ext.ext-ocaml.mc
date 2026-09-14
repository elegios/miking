include "map.mc"
include "ocaml/ast.mc"

-- Backed by lib/mi-stats. owl's in-place `~out:` forms are replaced by
-- Eigen::Map writes into the caller's buffer, so nothing is copied and no
-- Bigarray reshaping dance is needed -- the (m, n) pair is passed through and
-- used directly, where the owl bindings had to build a reshaped genarray view
-- around every call.
--
-- Generic over the element kind: ExtArr Float may be float32- or
-- float64-backed and mat-ext.mc's utests exercise both.

let impl = lam arg : { expr : String, ty : use Ast in Type }.
  { expr = arg.expr, ty = arg.ty, libraries = ["mi-stats"], cLibraries = [] }

let inplaceUnopTy = use OCamlTypeAst in
  tyarrows_ [tyint_, tyint_, otyopaque_, otyopaque_, otyunit_]

let matExtMap =
  use OCamlTypeAst in
  mapFromSeq cmpString [
    ("externalMatTranspose", [
      impl { expr = "Mi_stats.mat_transpose", ty = inplaceUnopTy }
    ]),
    ("externalMatElemExp", [
      impl { expr = "Mi_stats.mat_elem_exp", ty = inplaceUnopTy }
    ]),
    ("externalMatElemLog", [
      impl { expr = "Mi_stats.mat_elem_log", ty = inplaceUnopTy }
    ]),
    ("externalMatElemMul", [
      impl { expr = "Mi_stats.mat_elem_mul",
             ty = tyarrows_ [
               tyint_, tyint_, otyopaque_, otyopaque_, otyopaque_, otyunit_] }
    ]),
    -- Stan's matrix_exp (scaling-and-squaring Pade), always evaluated in
    -- double and written back in the input's kind.
    ("externalMatExp", [
      impl { expr = "Mi_stats.mat_exp",
             ty = tyarrows_ [tyint_, tyint_, otyopaque_, otyopaque_] }
    ])
  ]
