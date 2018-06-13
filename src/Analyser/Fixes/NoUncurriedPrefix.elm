module Analyser.Fixes.NoUncurriedPrefix exposing (fixer)

import Analyser.Checks.NoUncurriedPrefix as NoUncurriedPrefixCheck
import Analyser.Fixes.Base exposing (Fixer, Patch(..))
import Analyser.Fixes.FileContent as FileContent
import Analyser.Messages.Data as Data exposing (MessageData)
import Elm.Syntax.File exposing (File)
import Elm.Syntax.Module exposing (Module(..))
import Elm.Syntax.Range as Range exposing (Range)
import Regex


fixer : Fixer
fixer =
    Fixer (.key <| .info <| NoUncurriedPrefixCheck.checker) fix "Reorder and format"


fix : ( String, File ) -> MessageData -> Patch
fix input messageData =
    case
        Maybe.map3 (,,)
            (Data.getRange "range" messageData)
            (Data.getRange "arg1" messageData)
            (Data.getRange "arg2" messageData)
    of
        Just ( range, argRange1, argRange2 ) ->
            updateExpression input ( range, argRange1, argRange2 )

        Nothing ->
            IncompatibleData


parenRegex : Maybe Regex.Regex
parenRegex =
    Regex.fromString "[()]"


updateExpression : ( String, File ) -> ( Range, Range, Range ) -> Patch
updateExpression ( content, _ ) ( opRange, argRange1, argRange2 ) =
    let
        op =
            let
                original =
                    FileContent.getStringAtRange opRange content
            in
            parenRegex
                -- Drop the surrounding parens
                |> Maybe.map (\r -> Regex.replace r (\_ -> "") original)
                |> Maybe.withDefault original

        arg1 =
            FileContent.getStringAtRange argRange1 content

        arg2 =
            FileContent.getStringAtRange argRange2 content

        range =
            Range.combine [ opRange, argRange2 ]
    in
    if op == "," then
        -- Special case for the two-tuple operator, which needs surrounding parens
        content
            |> FileContent.replaceRangeWith range ("(" ++ arg1 ++ ", " ++ arg2 ++ ")")
            |> Patched
    else
        -- Normal case for all other operators
        content
            |> FileContent.replaceRangeWith range (arg1 ++ " " ++ op ++ " " ++ arg2)
            |> Patched
