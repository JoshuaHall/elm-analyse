module Registry exposing (Registry, fromValue, lookup)

import Json.Decode as JD exposing (Value)
import Registry.Package as Package exposing (Package)


type Registry
    = Registry (Result String (List Package))


lookup : String -> Registry -> Maybe Package
lookup key (Registry values) =
    values
        |> Result.toMaybe
        |> Maybe.andThen (List.filter (.name >> (==) key) >> List.head)


fromValue : Value -> Registry
fromValue value =
    Registry <| Result.mapError Debug.toString <| JD.decodeValue (JD.list Package.decode) value
