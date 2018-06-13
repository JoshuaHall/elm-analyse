module Analyser.Checks.DropConcatOfLists exposing (checker)

import AST.Ranges as Range
import ASTUtil.Inspector as Inspector exposing (Order(..), defaultConfig)
import Analyser.Checks.Base exposing (Checker)
import Analyser.Configuration exposing (Configuration)
import Analyser.FileContext exposing (FileContext)
import Analyser.Messages.Data as Data exposing (MessageData)
import Analyser.Messages.Schema as Schema
import Elm.Syntax.Expression exposing (Expression(..))
import Elm.Syntax.Ranged exposing (Ranged)


checker : Checker
checker =
    { check = scan
    , info =
        { key = "DropConcatOfLists"
        , name = "Drop Concat Of Lists"
        , description = "If you concatenate two lists ([...] ++ [...]), then you can merge them into one list."
        , schema =
            Schema.schema
                |> Schema.rangeProp "range"
        }
    }


type alias Context =
    List MessageData


scan : FileContext -> Configuration -> List MessageData
scan fileContext _ =
    Inspector.inspect
        { defaultConfig
            | onExpression = Post onExpression
        }
        fileContext.ast
        []


onExpression : Ranged Expression -> Context -> Context
onExpression ( r, inner ) context =
    case inner of
        OperatorApplication "++" _ ( _, ListExpr _ ) ( _, ListExpr _ ) ->
            let
                range =
                    r
            in
            (Data.init
                (String.concat
                    [ "Joining two literal lists with `++`, but instead you can just join the lists. At "
                    , Range.rangeToString range
                    ]
                )
                |> Data.addRange "range" range
            )
                :: context

        _ ->
            context
