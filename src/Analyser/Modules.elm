module Analyser.Modules exposing (Modules, build, decode, empty, encode)

import Analyser.Checks.UnusedDependency as UnusedDependency
import Analyser.CodeBase exposing (CodeBase)
import Analyser.FileContext as FileContext exposing (FileContext)
import Analyser.Files.Types exposing (LoadedSourceFiles)
import Elm.Dependency exposing (Dependency)
import Elm.Syntax.Base exposing (ModuleName)
import Json.Decode as JD exposing (Decoder)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as JE exposing (Value)


type alias Modules =
    { projectModules : List ModuleName
    , dependencies : List ( ModuleName, ModuleName )
    }


empty : Modules
empty =
    { projectModules = []
    , dependencies = []
    }


build : CodeBase -> LoadedSourceFiles -> ( List Dependency, Modules )
build codeBase sources =
    let
        files =
            FileContext.build codeBase sources
    in
    ( UnusedDependency.check codeBase files
    , { projectModules = List.map .moduleName files
      , dependencies = List.concatMap edgesInFile files
      }
    )


edgesInFile : FileContext -> List ( List String, List String )
edgesInFile file =
    file.ast.imports
        |> List.map .moduleName
        |> List.map (Tuple.pair file.moduleName)


decode : JD.Decoder Modules
decode =
    JD.succeed Modules
        |> required "projectModules" (JD.list decodeModuleName)
        |> required "dependencies" (JD.list decodeDependency)


tupleFromLIst : List a -> JD.Decoder ( a, a )
tupleFromLIst x =
    case x of
        [ a, b ] ->
            JD.succeed ( a, b )

        _ ->
            JD.fail "Not a tuple"


encode : Modules -> Value
encode e =
    JE.object
        [ ( "projectModules", JE.list encodeModuleName e.projectModules )
        , ( "dependencies", JE.list encodeDependency e.dependencies )
        ]


encodeDependency : ( ModuleName, ModuleName ) -> JE.Value
encodeDependency ( x, y ) =
    JE.list encodeModuleName [ x, y ]


decodeDependency : Decoder ( ModuleName, ModuleName )
decodeDependency =
    JD.list decodeModuleName |> JD.andThen tupleFromLIst


decodeModuleName : Decoder ModuleName
decodeModuleName =
    JD.string |> JD.map (String.split ".")


encodeModuleName : ModuleName -> Value
encodeModuleName =
    String.join "." >> JE.string
