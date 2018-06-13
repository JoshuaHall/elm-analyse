module Client.Routing exposing (Route(..), fromLocation, toUrl)

import Browser.Navigation as Navigation
import Url exposing (Url)
import Url.Parser as Url


type Route
    = Dashboard
    | Dependencies
    | Modules
    | Messages
    | FileTree
    | PackageDependencies
    | NotFound


parser : Url.Parser (Route -> c) c
parser =
    Url.oneOf
        [ Url.map Dashboard Url.top
        , Url.map Dashboard (Url.s "dashboard")
        , Url.map Dependencies (Url.s "dependencies")
        , Url.map Modules (Url.s "modules")
        , Url.map Messages (Url.s "messages")
        , Url.map FileTree (Url.s "tree")
        , Url.map PackageDependencies (Url.s "package-dependencies")
        ]


fromLocation : Url -> Route
fromLocation =
    Url.parse parser >> Maybe.withDefault NotFound


toUrl : Route -> String
toUrl route =
    "#"
        ++ (case route of
                Dependencies ->
                    "dependencies"

                Dashboard ->
                    "dashboard"

                Modules ->
                    "modules"

                Messages ->
                    "messages"

                FileTree ->
                    "tree"

                PackageDependencies ->
                    "package-dependencies"

                NotFound ->
                    "/"
           )
