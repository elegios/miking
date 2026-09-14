include "map.mc"
include "ocaml/ast.mc"

-- Backed by lib/mi-stats. Tensor[Float] is a float64 C-layout genarray, so
-- this half needs no kind dispatch. expm is Stan's matrix_exp; the rest is
-- Eigen, replacing owl's Owl_dense.Matrix.D infix operators.

let impl = lam arg : { expr : String, ty : use Ast in Type }.
  { expr = arg.expr, ty = arg.ty, libraries = ["mi-stats"], cLibraries = [] }

let matrixExtMap =
  use OCamlTypeAst in
  mapFromSeq cmpString [
    ("externalMatrixExponential", [
      impl { expr = "Mi_stats.matrix_exp",
             ty = tyarrows_ [otygenarrayclayoutfloat_, otygenarrayclayoutfloat_] }
    ]),
    ("externalMatrixTranspose", [
      impl { expr = "Mi_stats.matrix_transpose",
             ty = tyarrows_ [otygenarrayclayoutfloat_, otygenarrayclayoutfloat_] }
    ]),
    -- owl's ( $* ) took the scalar first; so does this.
    ("externalMatrixMulFloat", [
      impl { expr = "Mi_stats.matrix_mul_float",
             ty = tyarrows_ [tyfloat_, otygenarrayclayoutfloat_,
                             otygenarrayclayoutfloat_] }
    ]),
    ("externalMatrixMul", [
      impl { expr = "Mi_stats.matrix_mul",
             ty = tyarrows_ [otygenarrayclayoutfloat_, otygenarrayclayoutfloat_,
                             otygenarrayclayoutfloat_] }
    ]),
    ("externalMatrixElemMul", [
      impl { expr = "Mi_stats.matrix_elem_mul",
             ty = tyarrows_ [otygenarrayclayoutfloat_, otygenarrayclayoutfloat_,
                             otygenarrayclayoutfloat_] }
    ]),
    ("externalMatrixElemAdd", [
      impl { expr = "Mi_stats.matrix_elem_add",
             ty = tyarrows_ [otygenarrayclayoutfloat_, otygenarrayclayoutfloat_,
                             otygenarrayclayoutfloat_] }
    ])
  ]
