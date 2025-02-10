-- This file provides a means to update locally-bound identifiers to
-- use new `Name`s. This is useful to maintain the symbolize invariant
-- (all bindings introduce distinct `Name`s) when inserting duplicated
-- code, by resymbolizing the copy before insertion.
--
-- Note that we assume that the input is already symbolized, and that
-- the symbolize invariant holds for it in isolation. Free variables
-- will not be updated.

include "mexpr/ast.mc"

lang Resymbolize = Ast
  sem resymbolizeBindings : Expr -> Expr
  sem resymbolizeBindings =
  | ast -> resymbolizeBindingsExpr (mapEmpty nameCmp) ast

  sem resymbolizeBindingsExpr : Map Name Name -> Expr -> Expr
  sem resymbolizeBindingsExpr nameMap =
  | t ->
    let t = smap_Expr_Expr (resymbolizeBindingsExpr nameMap) t in
    let t = smap_Expr_Type (resymbolizeBindingsType nameMap) t in
    let t = smap_Expr_TypeLabel (resymbolizeBindingsType nameMap) t in
    withType (resymbolizeBindingsType nameMap (tyTm t)) t

  sem resymbolizeBindingsPat : Map Name Name -> Pat -> (Map Name Name, Pat)
  sem resymbolizeBindingsPat nameMap =
  | p -> smapAccumL_Pat_Pat resymbolizeBindingsPat nameMap p

  sem resymbolizeBindingsType : Map Name Name -> Type -> Type
  sem resymbolizeBindingsType nameMap =
  | ty -> smap_Type_Type (resymbolizeBindingsType nameMap) ty
end

lang ResymbolizeVar = Resymbolize + VarAst
  sem resymbolizeBindingsExpr nameMap =
  | TmVar t ->
    let newId =
      match mapLookup t.ident nameMap with Some newId then newId
      else t.ident
    in
    TmVar {t with ident = newId, ty = resymbolizeBindingsType nameMap t.ty}
end

lang ResymbolizeLam = Resymbolize + LamAst
  sem resymbolizeBindingsExpr nameMap =
  | TmLam t ->
    let newId = nameSetNewSym t.ident in
    let nameMap = mapInsert t.ident newId nameMap in
    TmLam {t with ident = newId,
                  tyAnnot = resymbolizeBindingsType nameMap t.tyAnnot,
                  tyParam = resymbolizeBindingsType nameMap t.tyParam,
                  body = resymbolizeBindingsExpr nameMap t.body,
                  ty = resymbolizeBindingsType nameMap t.ty}
end

lang ResymbolizeLet = Resymbolize + LetAst
  sem resymbolizeBindingsExpr nameMap =
  | TmLet t ->
    let body = resymbolizeBindingsExpr nameMap t.body in
    let newId = nameSetNewSym t.ident in
    let nameMap = mapInsert t.ident newId nameMap in
    TmLet {t with ident = newId,
                  tyAnnot = resymbolizeBindingsType nameMap t.tyAnnot,
                  tyBody = resymbolizeBindingsType nameMap t.tyBody,
                  body = body,
                  inexpr = resymbolizeBindingsExpr nameMap t.inexpr,
                  ty = resymbolizeBindingsType nameMap t.ty}
end

lang ResymbolizeRecLets = Resymbolize + RecLetsAst
  sem resymbolizeBindingsExpr nameMap =
  | TmRecLets t ->
    let addNewIdBinding = lam nameMap. lam bind.
      let newId = nameSetNewSym bind.ident in
      (mapInsert bind.ident newId nameMap, {bind with ident = newId})
    in
    match mapAccumL addNewIdBinding nameMap t.bindings with (nameMap, bindings) in
    let resymbolizeBind = lam bind.
      {bind with tyAnnot = resymbolizeBindingsType nameMap bind.tyAnnot,
                 tyBody = resymbolizeBindingsType nameMap bind.tyBody,
                 body = resymbolizeBindingsExpr nameMap bind.body}
    in
    let bindings = map resymbolizeBind bindings in
    TmRecLets {t with bindings = bindings,
                      inexpr = resymbolizeBindingsExpr nameMap t.inexpr,
                      ty = resymbolizeBindingsType nameMap t.ty}
end

lang ResymbolizeType = Resymbolize + TypeAst
  sem resymbolizeBindingsExpr nameMap =
  | TmType t ->
    let newId = nameSetNewSym t.ident in
    let nameMap = mapInsert t.ident newId nameMap in
    TmType {t with ident = newId,
                   tyIdent = resymbolizeBindingsType nameMap t.tyIdent,
                   inexpr = resymbolizeBindingsExpr nameMap t.inexpr,
                   ty = resymbolizeBindingsType nameMap t.ty}
end

lang ResymbolizeData = Resymbolize + DataAst
  sem resymbolizeBindingsExpr nameMap =
  | TmConDef t ->
    let newId = nameSetNewSym t.ident in
    let nameMap = mapInsert t.ident newId nameMap in
    TmConDef {t with ident = newId,
                     inexpr = resymbolizeBindingsExpr nameMap t.inexpr,
                     ty = resymbolizeBindingsType nameMap t.ty}
  | TmConApp t ->
    let newId =
      match mapLookup t.ident nameMap with Some newId then newId
      else t.ident
    in
    TmConApp {t with ident = newId,
                     body = resymbolizeBindingsExpr nameMap t.body,
                     ty = resymbolizeBindingsType nameMap t.ty}
end

lang ResymbolizeMatch = Resymbolize + MatchAst
  sem resymbolizeBindingsExpr nameMap =
  | TmMatch t ->
    let target = resymbolizeBindingsExpr nameMap t.target in
    match resymbolizeBindingsPat nameMap t.pat with (thnNameMap, pat) in
    TmMatch {t with target = target, pat = pat,
                    thn = resymbolizeBindingsExpr thnNameMap t.thn,
                    els = resymbolizeBindingsExpr nameMap t.els,
                    ty = resymbolizeBindingsType nameMap t.ty}
end

lang ResymbolizeNamedPat = Resymbolize + NamedPat
  sem resymbolizeBindingsPat nameMap =
  | PatNamed (t & {ident = PName id}) ->
    let newId = nameSetNewSym id in
    (mapInsert id newId nameMap, PatNamed {t with ident = PName newId})
end

lang ResymbolizeSeqEdgePat = Resymbolize + SeqEdgePat
  sem resymbolizeBindingsPat nameMap =
  | PatSeqEdge (t & {middle = PName id}) ->
    let newId = nameSetNewSym id in
    (mapInsert id newId nameMap, PatSeqEdge {t with middle = PName newId})
end

lang ResymbolizeDataPat = Resymbolize + DataPat
  sem resymbolizeBindingsPat nameMap =
  | PatCon t ->
    match mapLookup t.ident nameMap with Some newId then
      (nameMap, PatCon {t with ident = newId})
    else (nameMap, PatCon t)
end

lang ResymbolizeConType = Resymbolize + ConTypeAst
  sem resymbolizeBindingsType nameMap =
  | TyCon t ->
    match mapLookup t.ident nameMap with Some newId then
      TyCon {t with ident = newId}
    else TyCon t
end

lang ResymbolizeVarType = Resymbolize + VarTypeAst
  sem resymbolizeBindingsType nameMap =
  | TyVar t ->
    match mapLookup t.ident nameMap with Some newId then
      TyVar {t with ident = newId}
    else TyVar t
end

lang ResymbolizeAllType = Resymbolize + AllTypeAst
  sem resymbolizeBindingsType nameMap =
  | TyAll t ->
    let newId = nameSetNewSym t.ident in
    let nameMap = mapInsert t.ident newId nameMap in
    TyAll {t with ident = newId,
                  ty = resymbolizeBindingsType nameMap t.ty}
end

lang MExprResymbolize
  = MExprAst
  + ResymbolizeLam
  + ResymbolizeLet
  + ResymbolizeRecLets
  + ResymbolizeType
  + ResymbolizeData
  + ResymbolizeMatch
  + ResymbolizeNamedPat
  + ResymbolizeSeqEdgePat
  + ResymbolizeDataPat
  + ResymbolizeConType
  + ResymbolizeVarType
  + ResymbolizeAllType
  + ResymbolizeVar
end
