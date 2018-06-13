module Analyser.FileContext exposing (FileContext, build, moduleName)

import Analyser.CodeBase as CodeBase exposing (CodeBase)
import Analyser.FileRef exposing (FileRef)
import Analyser.Files.Types exposing (LoadedSourceFile)
import Debug as SafeDebug
import Elm.Interface as Interface exposing (Interface)
import Elm.Processing as Processing exposing (ProcessContext)
import Elm.RawFile as RawFile exposing (RawFile)
import Elm.Syntax.Base exposing (ModuleName)
import Elm.Syntax.File exposing (File)


moduleName : RawFile -> ModuleName
moduleName rf =
    case RawFile.moduleName rf of
        Nothing ->
            SafeDebug.todo "Legacy"

        Just x ->
            x


type alias FileContext =
    { interface : Interface
    , moduleName : ModuleName
    , ast : File
    , content : String
    , file : FileRef
    }


build : CodeBase -> List LoadedSourceFile -> List FileContext
build codeBase selected =
    let
        moduleIndex =
            CodeBase.processContext codeBase
    in
    List.filterMap (buildForFile moduleIndex) selected


buildForFile : ProcessContext -> LoadedSourceFile -> Maybe FileContext
buildForFile moduleIndex ( fileContent, r ) =
    case r of
        Err _ ->
            Nothing

        Ok l ->
            Just <|
                { moduleName = moduleName l
                , ast = Processing.process moduleIndex l
                , file =
                    { path = fileContent.path
                    , version = Maybe.withDefault "" fileContent.sha1
                    }
                , content = fileContent.content |> Maybe.withDefault ""
                , interface = Interface.build l
                }
