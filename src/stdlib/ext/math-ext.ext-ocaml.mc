include "map.mc"
include "ocaml/ast.mc"

let impl = lam arg : { expr : String, ty : use Ast in Type }.
  { expr = arg.expr, ty = arg.ty, libraries = [], cLibraries = [] }

let mathExtMap =
  use OCamlTypeAst in
  mapFromSeq cmpString [
    ("externalExp", [
      impl { expr = "Float.exp", ty = tyarrow_ tyfloat_ tyfloat_ }
    ]),
    ("externalLog", [
      impl { expr = "Float.log", ty = tyarrow_ tyfloat_ tyfloat_ }
    ]),
    ("externalAtan", [
      impl { expr = "Float.atan", ty = tyarrow_ tyfloat_ tyfloat_ }
    ]),
    ("externalSin", [
      impl { expr = "Float.sin", ty = tyarrow_ tyfloat_ tyfloat_ }
    ]),
    ("externalCos", [
      impl { expr = "Float.cos", ty = tyarrow_ tyfloat_ tyfloat_ }
    ]),
    ("externalAtan2", [
      impl { expr = "Float.atan2", ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_] }
    ]),
    ("externalPow", [
      impl { expr = "Float.pow", ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_] }
    ]),
    ("externalSqrt", [
      impl { expr = "Float.sqrt", ty = tyarrow_ tyfloat_ tyfloat_ }
    ]),
    -- The only two values in this file that are not plain Float functions.
    -- Backed by lib/mi-stats (Stan Math's lgamma and
    -- binomial_coefficient_log); everything above routes to OCaml's Float.
    ("externalLogGamma", [
      { expr = "Mi_stats.log_gamma",
        ty = tyarrows_ [tyfloat_, tyfloat_],
        libraries = ["mi-stats"],
        cLibraries = []
      }
    ]),
    ("externalLogCombination", [
      { expr = "Mi_stats.log_combination",
        ty = tyarrows_ [tyint_, tyint_, tyfloat_],
        libraries = ["mi-stats"],
        cLibraries = []
      }
    ])
  ]
