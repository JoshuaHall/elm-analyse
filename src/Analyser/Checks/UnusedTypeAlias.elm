module Analyser.Checks.UnusedTypeAlias exposing (checker)

import AST.Ranges as Range
import ASTUtil.Inspector as Inspector exposing (Order(..), defaultConfig)
import Analyser.Checks.Base exposing (Checker)
import Analyser.Configuration exposing (Configuration)
import Analyser.FileContext exposing (FileContext)
import Analyser.Messages.Data as Data exposing (MessageData)
import Analyser.Messages.Schema as Schema
import Dict exposing (Dict)
import Elm.Interface as Interface
import Elm.Syntax.Range as Range exposing (Range)
import Elm.Syntax.Ranged exposing (Ranged)
import Elm.Syntax.TypeAlias exposing (TypeAlias)
import Elm.Syntax.TypeAnnotation exposing (TypeAnnotation(..))
import Tuple3


checker : Checker
checker =
    { check = scan
    , info =
        { key = "UnusedTypeAlias"
        , name = "Unused Type Alias"
        , description = "You defined a type alias, but you do not use it in any signature or expose it."
        , schema =
            Schema.schema
                |> Schema.varProp "varName"
                |> Schema.rangeProp "range"
        }
    }


type alias Context =
    Dict String ( String, Range, Int )


scan : FileContext -> Configuration -> List MessageData
scan fileContext _ =
    let
        collectedAliased : Context
        collectedAliased =
            Inspector.inspect
                { defaultConfig | onTypeAlias = Post onTypeAlias }
                fileContext.ast
                Dict.empty
    in
    Inspector.inspect
        { defaultConfig
            | onTypeAnnotation = Post onTypeAnnotation
            , onFunctionOrValue = Post onFunctionOrValue
        }
        fileContext.ast
        collectedAliased
        |> Dict.toList
        |> List.filter (Tuple.second >> Tuple3.third >> (<) 0 >> not)
        |> List.filter (Tuple.first >> (\a -> Interface.exposesAlias a fileContext.interface) >> not)
        |> List.map (Tuple.mapSecond Tuple3.second)
        |> List.map buildMessageData


buildMessageData : ( String, Range ) -> MessageData
buildMessageData ( varName, range ) =
    Data.init
        (String.concat
            [ "Type alias `"
            , varName
            , "` is not used at "
            , Range.rangeToString range
            ]
        )
        |> Data.addVarName "varName" varName
        |> Data.addRange "range" range


markTypeAlias : String -> Context -> Context
markTypeAlias key context =
    Dict.update key (Maybe.map (Tuple3.mapThird ((+) 1))) context


onTypeAnnotation : Ranged TypeAnnotation -> Context -> Context
onTypeAnnotation ( _, typeAnnotation ) context =
    case typeAnnotation of
        Typed [] x _ ->
            markTypeAlias x context

        _ ->
            context


onFunctionOrValue : String -> Context -> Context
onFunctionOrValue =
    markTypeAlias


onTypeAlias : Ranged TypeAlias -> Context -> Context
onTypeAlias ( range, typeAlias ) context =
    Dict.insert typeAlias.name ( typeAlias.name, range, 0 ) context
