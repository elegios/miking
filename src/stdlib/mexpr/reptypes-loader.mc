include "reptypes.mc"
include "mlang/loader.mc"

lang MExprRepAnalysis
  = MetaVarTypeCmp
  + MExprCmp
  + MExprPrettyPrint
  + MExprRepTypesAnalysis
  + RepTypesCmp
  + RepTypesPrettyPrint
end

lang MExprRepTypesSolverBase
  = AllTypeGeneralize
  + MetaVarTypeCmp
  + MetaVarTypeGeneralize
  + MetaVarTypePrettyPrint
  + MExprAst
  + MExprCmp
  + MExprPrettyPrint
  + MExprUnify
  + MExprResymbolize
  + ReprTypeUnify
  + RepTypesAst
  + RepTypesCmp
  + RepTypesPrettyPrint
  + RepTypesSolveAndReconstruct
  + TyWildUnify
  + VarTypeGeneralize
end

lang RepTypesLoader = MCoreLoader + OpMLangDeclAst + OpImplDeclAst + ReprMLangDeclAst
  syn Hook =
  | RepTypesHook
    { typeCheckLeaveMeta : Expr -> Expr
    , reprSolve : Expr -> [Expr]
    }

  -- NOTE(vipa, 2025-02-07): The first function should be
  -- typeCheckLeaveMeta with the appropriate set of language fragments
  -- merged in (probably based on MExprRepAnalysis). It shouldn't be
  -- the same as the normal type check composition, because this one
  -- should do repr analysis instead. The second should be reprSolve,
  -- probably based on MExprRepTypesSolverBase, partially applied to
  -- an appropriate value of type ReprSolverOptions.
  sem enableRepTypes : (Expr -> Expr) -> (Expr -> [Expr]) -> Loader -> Loader
  sem enableRepTypes typeCheckLeaveMeta reprSolve = | loader ->
    if hasHook (lam x. match x with RepTypesHook _ then true else false) loader then loader else

    let hook = RepTypesHook
      { typeCheckLeaveMeta = typeCheckLeaveMeta
      , reprSolve = reprSolve
      } in
    addHook loader hook

  sem _postBuildFullAst loader ast = | RepTypesHook hook ->
    let ast = hook.typeCheckLeaveMeta ast in

    match hook.reprSolve ast with [ast] ++ _ then ast

    else errorSingle [infoTm ast] "Repr solving failed for the program"

  sem _addDefinition env =
  | DeclOp t ->
    let varEnv = mapInsert (nameGetStr t.ident) t.ident env.currentEnv.varEnv in
    symbolizeUpdateVarEnv env varEnv
  | DeclOpImpl _ ->
    -- NOTE(vipa, 2025-02-24): An OpImpl doesn't bind anything new, it
    -- just refers to a previously defined Op
    env
  | DeclRepr t ->
    let reprEnv = mapInsert (nameGetStr t.ident) t.ident env.currentEnv.reprEnv in
    symbolizeUpdateReprEnv env reprEnv
end
