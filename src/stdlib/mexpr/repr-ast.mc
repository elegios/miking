include "mexpr/ast.mc"
include "mlang/ast.mc"

-- NOTE(vipa, 2023-06-12): We assume a certain collection size and
-- explicitly evaluate the cost expression
type OpCost = Float

-- A representation unification variable, for use in the UCT analysis
type ReprContent
type ReprVar = Ref ReprContent
con UninitRepr : () -> ReprContent
con BotRepr :
  { sym : Symbol
  , scope : Int
  } -> ReprContent
con LinkRepr :
  -- Invariant: link may only point to a repr with <= scope
  ReprVar -> ReprContent

recursive let botRepr : ReprVar -> ReprVar = lam r.
  switch deref r
  case BotRepr _ | UninitRepr _ then r
  case LinkRepr x then
    let bot = botRepr x in
    modref r (LinkRepr bot);
    bot
  end
end


lang TyWildAst = Ast
  syn Type =
  | TyWild { info : Info }

  sem tyWithInfo info =
  | TyWild x -> TyWild {x with info = info}

  sem infoTy =
  | TyWild x -> x.info
end

lang ReprTypeAst = Ast
 syn Type =
 | TyRepr { info : Info, arg : Type, repr : ReprVar }

 sem tyWithInfo info =
 | TyRepr x -> TyRepr {x with info = info}

 sem infoTy =
 | TyRepr x -> x.info

 sem smapAccumL_Type_Type f acc =
 | TyRepr x ->
   match f acc x.arg with (acc, arg) in
   (acc, TyRepr { x with arg = arg })
end

lang ReprSubstAst = Ast
  syn Type =
  | TySubst { info : Info, arg : Type, subst : Name }

  sem tyWithInfo info =
  | TySubst x -> TySubst {x with info = info}

  sem infoTy =
  | TySubst x -> x.info

  sem smapAccumL_Type_Type f acc =
  | TySubst x ->
   match f acc x.arg with (acc, arg) in
   (acc, TySubst { x with arg = arg })
end

lang OpDeclAst = Ast
  syn Expr =
  | TmOpDecl { info : Info, ident : Name, tyAnnot : Type, ty : Type, inexpr : Expr }

  sem tyTm =
  | TmOpDecl x -> x.ty

  sem withType ty =
  | TmOpDecl x -> TmOpDecl {x with ty = ty}

  sem withInfo info =
  | TmOpDecl x -> TmOpDecl {x with info = info}

  sem infoTm =
  | TmOpDecl x -> x.info

  sem smapAccumL_Expr_Expr f acc =
  | TmOpDecl x ->
    match f acc x.inexpr with (env, inexpr) in
    (env, TmOpDecl {x with inexpr = inexpr})

  sem smapAccumL_Expr_Type f acc =
  | TmOpDecl x ->
    match f acc x.tyAnnot with (env, tyAnnot) in
    (env, TmOpDecl {x with tyAnnot = tyAnnot})
end

lang OpMLangDeclAst = DeclAst
  syn Decl =
  | DeclOp
    { ident : Name
    , tyAnnot : Type
    , info : Info
    }

  sem infoDecl =
  | DeclOp x -> x.info

  sem declWithInfo info =
  | DeclOp x -> DeclOp {x with info = info}

  sem smapAccumL_Decl_Type f acc =
  | DeclOp x ->
    match f acc x.tyAnnot with (acc, tyAnnot) in
    (acc, DeclOp {x with tyAnnot = tyAnnot})
end

lang OpDeclAsDecl = ExprAsDecl + OpDeclAst + OpMLangDeclAst
  sem exprAsDecl =
  | TmOpDecl x -> Some
    ( DeclOp {ident = x.ident, tyAnnot = x.tyAnnot, info = x.info}
    , x.inexpr
    )

  sem declAsExpr inexpr =
  | DeclOp x -> TmOpDecl
    { ident = x.ident
    , tyAnnot = x.tyAnnot
    , info = x.info
    , ty = tyTm inexpr
    , inexpr = inexpr
    }
end

type ImplId = Int
lang OpImplAst = Ast
  type TmOpImplRec = use Ast in
    { ident : Name
    , implId : ImplId
    , reprScope : Int
    , metaLevel : Int
    , selfCost : OpCost
    , body : Expr
    , specType : Type
    , delayedReprUnifications : [(ReprVar, ReprVar)]
    , inexpr : Expr
    , ty : Type
    , info : Info
    }
  syn Expr =
  | TmOpImpl TmOpImplRec

  sem tyTm =
  | TmOpImpl x -> x.ty

  sem withType ty =
  | TmOpImpl x -> TmOpImpl {x with ty = ty}

  sem infoTm =
  | TmOpImpl x -> x.info

  sem smapAccumL_Expr_Expr f acc =
  | TmOpImpl x ->
    match f acc x.body with (acc, body) in
    match f acc x.inexpr with (acc, inexpr) in
    (acc, TmOpImpl {x with body = body, inexpr = inexpr})

  sem smapAccumL_Expr_Type f acc =
  | TmOpImpl x ->
    match f acc x.specType with (acc, specType) in
    (acc, TmOpImpl {x with specType = specType})
end

lang OpImplDeclAst = DeclAst
  syn Decl =
  | DeclOpImpl
    { ident : Name
    , implId : ImplId
    , reprScope : Int
    , metaLevel : Int
    , selfCost : OpCost
    , body : Expr
    , specType : Type
    , delayedReprUnifications : [(ReprVar, ReprVar)]
    , info : Info
    }

  sem infoDecl =
  | DeclOpImpl x -> x.info

  sem declWithInfo info =
  | DeclOpImpl x -> DeclOpImpl {x with info = info}

  sem smapAccumL_Decl_Expr f acc =
  | DeclOpImpl x ->
    match f acc x.body with (acc, body) in
    (acc, DeclOpImpl {x with body = body})

  sem smapAccumL_Decl_Type f acc =
  | DeclOpImpl x ->
    match f acc x.specType with (acc, specType) in
    (acc, DeclOpImpl {x with specType = specType})
end

lang OpImplAsDecl = ExprAsDecl + OpImplAst + OpImplDeclAst
  sem exprAsDecl =
  | TmOpImpl x -> Some
    ( DeclOpImpl {ident = x.ident, implId = x.implId, reprScope = x.reprScope, metaLevel = x.metaLevel, selfCost = x.selfCost, body = x.body, specType = x.specType, delayedReprUnifications = x.delayedReprUnifications, info = x.info}
    , x.inexpr
    )

  sem declAsExpr inexpr =
  | DeclOpImpl x -> TmOpImpl
    { ident = x.ident
    , implId = x.implId
    , reprScope = x.reprScope
    , metaLevel = x.metaLevel
    , selfCost = x.selfCost
    , body = x.body
    , specType = x.specType
    , delayedReprUnifications = x.delayedReprUnifications
    , info = x.info
    , ty = tyTm inexpr
    , inexpr = inexpr
    }
end

lang OpVarAst = Ast
  type TmOpVarRec = {ident : Name, ty : Type, info : Info, frozen : Bool, scaling : OpCost}
  syn Expr =
  | TmOpVar TmOpVarRec

  sem tyTm =
  | TmOpVar x -> x.ty

  sem withType ty =
  | TmOpVar x -> TmOpVar {x with ty = ty}

  sem infoTm =
  | TmOpVar x -> x.info

  sem withInfo info =
  | TmOpVar x -> TmOpVar {x with info = info}
end

lang ReprDeclAst = Ast
  syn Expr =
  | TmReprDecl
    { ident : Name
    , vars : [Name]
    , pat : Type
    , repr : Type
    , ty : Type
    , inexpr : Expr
    , info : Info
    }

  sem tyTm =
  | TmReprDecl x -> x.ty

  sem withType ty =
  | TmReprDecl x -> TmReprDecl {x with ty = ty}

  sem infoTm =
  | TmReprDecl x -> x.info

  sem withInfo info =
  | TmReprDecl x -> TmReprDecl {x with info = info}

  sem smapAccumL_Expr_Expr f acc =
  | TmReprDecl x ->
    match f acc x.inexpr with (acc, inexpr) in
    (acc, TmReprDecl {x with inexpr = inexpr})

  sem smapAccumL_Expr_Type f acc =
  | TmReprDecl x ->
    match f acc x.pat with (acc, pat) in
    match f acc x.repr with (acc, repr) in
    (acc, TmReprDecl {x with pat = pat, repr = repr})
end

lang ReprMLangDeclAst = DeclAst
  syn Decl =
  | DeclRepr
    { ident : Name
    , vars : [Name]
    , pat : Type
    , repr : Type
    , info : Info
    }

  sem infoDecl =
  | DeclRepr d -> d.info

  sem declWithInfo info =
  | DeclRepr d -> DeclRepr {d with info = info}

  sem smapAccumL_Decl_Type f acc =
  | DeclRepr x ->
    match f acc x.pat with (acc, pat) in
    match f acc x.repr with (acc, repr) in
    (acc, DeclRepr {x with pat = pat, repr = repr})
end

lang ReprAsDecl = ExprAsDecl + ReprDeclAst + ReprMLangDeclAst
  sem exprAsDecl =
  | TmReprDecl x -> Some
    ( DeclRepr {ident = x.ident, vars = x.vars, pat = x.pat, repr = x.repr, info = x.info}
    , x.inexpr
    )

  sem declAsExpr inexpr =
  | DeclRepr x -> TmReprDecl
    { ident = x.ident
    , vars = x.vars
    , pat = x.pat
    , repr = x.repr
    , info = x.info
    , inexpr = inexpr
    , ty = tyTm inexpr
    }
end

lang RepTypesAst = ReprTypeAst + ReprSubstAst + OpDeclAst + OpImplAst + OpVarAst + ReprDeclAst + TyWildAst
end

lang RepTypesAsDecl = OpDeclAsDecl + OpImplAsDecl + ReprAsDecl
end

type CollectedImpl = use Ast in
  { selfCost : OpCost
  , body : Expr
  , specType : Type
  , info : Info
  }

type ImplData = use Ast in
  { impls : Map SID [CollectedImpl]
  , reprs : Map Name {vars : [Name], pat : Type, repr : Type}
  }

let emptyImplData : ImplData =
  { impls = mapEmpty cmpSID
  , reprs = mapEmpty nameCmp
  }
let mergeImplData : ImplData -> ImplData -> ImplData = lam a. lam b.
  { impls = mapUnionWith concat a.impls b.impls
  , reprs = mapUnionWith (lam. lam. never) a.reprs b.reprs
  }
