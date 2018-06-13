module Analyser.Checks.UnnecessaryParens exposing (checker)

import AST.Ranges as Range
import ASTUtil.Inspector as Inspector exposing (Order(..), defaultConfig)
import Analyser.Checks.Base exposing (Checker)
import Analyser.Configuration exposing (Configuration)
import Analyser.FileContext exposing (FileContext)
import Analyser.Messages.Data as Data exposing (MessageData)
import Analyser.Messages.Schema as Schema
import Elm.Syntax.Expression as Expression exposing (CaseBlock, Expression(..), Function, Lambda)
import Elm.Syntax.Infix exposing (InfixDirection)
import Elm.Syntax.Range as Syntax exposing (Range)
import Elm.Syntax.Ranged exposing (Ranged)
import List.Extra as List
import Maybe.Extra as Maybe


checker : Checker
checker =
    { check = scan
    , info =
        { key = "UnnecessaryParens"
        , name = "Unnecessary Parens"
        , description = "If you want parenthesis, then you might want to look into Lisp."
        , schema =
            Schema.schema
                |> Schema.rangeProp "range"
        }
    }


type alias Context =
    List Syntax.Range


scan : FileContext -> Configuration -> List MessageData
scan fileContext _ =
    let
        x : Context
        x =
            Inspector.inspect
                { defaultConfig | onExpression = Post onExpression, onFunction = Post onFunction, onLambda = Post onLambda }
                fileContext.ast
                []
    in
    x
        |> List.uniqueBy Debug.toString
        |> List.map buildMessage


buildMessage : Range -> MessageData
buildMessage r =
    Data.init
        (String.concat
            [ "Unnecessary parens at "
            , Range.rangeToString r
            ]
        )
        |> Data.addRange "range" r


onFunction : Function -> Context -> Context
onFunction function context =
    case function.declaration.expression of
        ( range, ParenthesizedExpression _ ) ->
            range :: context

        _ ->
            context


onLambda : Lambda -> Context -> Context
onLambda lambda context =
    case lambda.expression of
        ( range, ParenthesizedExpression _ ) ->
            range :: context

        _ ->
            context


onExpression : Ranged Expression -> Context -> Context
onExpression ( range, expression ) context =
    case expression of
        ParenthesizedExpression inner ->
            onParenthesizedExpression range inner context

        OperatorApplication op dir left right ->
            onOperatorApplication op dir left right context

        Application parts ->
            onApplication parts context

        IfBlock a b c ->
            onIfBlock a b c context

        CaseExpression caseBlock ->
            onCaseBlock caseBlock context

        RecordExpr parts ->
            onRecord parts context

        RecordUpdateExpression recordUpdate ->
            onRecord recordUpdate.updates context

        TupledExpression x ->
            onTuple x context

        ListExpr x ->
            onListExpr x context

        _ ->
            context


onListExpr : List (Ranged Expression) -> Context -> Context
onListExpr exprs context =
    List.filterMap getParenthesized exprs
        |> List.map Tuple.first
        |> (\a -> a ++ context)


onTuple : List (Ranged Expression) -> Context -> Context
onTuple exprs context =
    List.filterMap getParenthesized exprs
        |> List.map Tuple.first
        |> (\a -> a ++ context)


onRecord : List ( String, Ranged Expression ) -> Context -> Context
onRecord fields context =
    fields
        |> List.filterMap (Tuple.second >> getParenthesized)
        |> List.map Tuple.first
        |> (\a -> a ++ context)


onCaseBlock : CaseBlock -> Context -> Context
onCaseBlock caseBlock context =
    case getParenthesized caseBlock.expression of
        Just ( range, _ ) ->
            range :: context

        Nothing ->
            context


onIfBlock : Ranged Expression -> Ranged Expression -> Ranged Expression -> Context -> Context
onIfBlock clause thenBranch elseBranch context =
    [ clause, thenBranch, elseBranch ]
        |> List.filterMap getParenthesized
        |> List.map Tuple.first
        |> (\a -> a ++ context)


onApplication : List (Ranged Expression) -> Context -> Context
onApplication parts context =
    List.head parts
        |> Maybe.andThen getParenthesized
        |> Maybe.filter (Tuple.second >> Tuple.second >> Expression.isOperatorApplication >> not)
        |> Maybe.filter (Tuple.second >> Tuple.second >> Expression.isCase >> not)
        |> Maybe.map Tuple.first
        |> Maybe.map (\a -> a :: context)
        |> Maybe.withDefault context


onOperatorApplication : String -> InfixDirection -> Ranged Expression -> Ranged Expression -> Context -> Context
onOperatorApplication _ _ left right context =
    let
        fixHandSide : Ranged Expression -> Maybe Syntax.Range
        fixHandSide =
            getParenthesized
                >> Maybe.filter (Tuple.second >> operatorHandSideAllowedParens >> not)
                >> Maybe.map Tuple.first
    in
    [ fixHandSide left
    , fixHandSide right
    ]
        |> List.filterMap identity
        |> (\a -> a ++ context)


operatorHandSideAllowedParens : Ranged Expression -> Bool
operatorHandSideAllowedParens ( _, expr ) =
    List.any ((|>) expr)
        [ Expression.isOperatorApplication, Expression.isIfElse, Expression.isCase, Expression.isLet, Expression.isLambda ]


onParenthesizedExpression : Syntax.Range -> Ranged Expression -> Context -> Context
onParenthesizedExpression range ( _, expression ) context =
    case expression of
        RecordAccess _ _ ->
            range :: context

        RecordAccessFunction _ ->
            range :: context

        RecordUpdateExpression _ ->
            range :: context

        RecordExpr _ ->
            range :: context

        TupledExpression _ ->
            range :: context

        ListExpr _ ->
            range :: context

        FunctionOrValue _ ->
            range :: context

        Integer _ ->
            range :: context

        Floatable _ ->
            range :: context

        CharLiteral _ ->
            range :: context

        Literal _ ->
            range :: context

        QualifiedExpr _ _ ->
            range :: context

        _ ->
            context


getParenthesized : Ranged Expression -> Maybe ( Range, Ranged Expression )
getParenthesized ( r, e ) =
    case e of
        ParenthesizedExpression p ->
            Just ( r, p )

        _ ->
            Nothing
