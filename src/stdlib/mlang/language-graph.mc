include "ast.mc"
include "mexpr/pprint.mc"

lang LangGraph = MLangTopLevel + LangDeclAst + MExprIdentifierPrettyPrint
  sem langGenItem : PprintEnv -> Decl -> (PprintEnv, String)
  sem langGenItem env =
  | _ -> (env, "")
  | DeclLang x ->
    match pprintConName env x.ident with (env, ident) in
    match mapAccumL pprintConName env x.includes with (env, includes) in
    let info2str = lam i.
      let f = lam c.
        switch c
        case '<' then "&lt"
        case '>' then "&gt"
        case '&' then "&amp"
        case c then [c]
        end in
      joinMap f (info2str i) in
    ( env
    , join
      [ "  ", ident, "\n" --"[label=<", ident, "<br/><font point-size=\"8\">", info2str x.info, "</font>>]\n"
      , "  ", ident, " -> {", strJoin "," includes, "}\n"
      ]
    )

  sem genForProgram : MLangProgram -> String
  sem genForProgram = | prog ->
    match mapAccumL langGenItem pprintEnvEmpty prog.decls with (_, nodesAndEdges) in
    join
      [ "digraph {\n"
      , join nodesAndEdges
      , "}"
      ]

  sem jsonGenItem : PprintEnv -> Decl -> (PprintEnv, Option JsonValue)
  sem jsonGenItem env =
  | _ -> (env, None ())
  | DeclLang x ->
    match pprintConName env x.ident with (env, ident) in
    match mapAccumL pprintConName env x.includes with (env, includes) in
    let info = info2str x.info in
    match strSplit "/" info with dirs ++ [_] in
    let obj = JsonObject (mapFromSeq cmpString
      [ ("source", JsonString ident)
      , ("target", JsonArray (map (lam x. JsonString x) includes))
      , ("label", JsonString (join [ident, "\n", info2str x.info]))
      , ("kind", JsonString (strJoin "/" dirs))
      ]) in
    (env, Some obj)

  sem jsonGenForProgram : MLangProgram -> JsonValue
  sem jsonGenForProgram = | prog ->
    match mapAccumL jsonGenItem pprintEnvEmpty prog.decls with (_, items) in
    JsonArray (filterOption items)
end
