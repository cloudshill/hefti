module Api.Endpoint exposing (Endpoint, entry, entryId, login, request, week)

import Http
import String
import Url.Builder exposing (QueryParameter)
import Username exposing (Username)


{-| Http.request, except it takes an Endpoint instead of a Url.
-}
request :
    { body : Http.Body
    , expect : Http.Expect a
    , headers : List Http.Header
    , method : String
    , timeout : Maybe Float
    , url : Endpoint
    , tracker : Maybe String
    }
    -> Cmd a
request config =
    Http.request
        { body = config.body
        , expect = config.expect
        , headers = config.headers
        , method = config.method
        , timeout = config.timeout
        , url = unwrap config.url
        , tracker = config.tracker
        }



-- TYPES


{-| Get a URL to the Conduit API.

This is not publicly exposed, because we want to make sure the only way to get one of these URLs is from this module.

-}
type Endpoint
    = Endpoint String


unwrap : Endpoint -> String
unwrap (Endpoint str) =
    str


url : List String -> List QueryParameter -> Endpoint
url paths queryParams =
    -- NOTE: Url.Builder takes care of percent-encoding special URL characters.
    -- See https://package.elm-lang.org/packages/elm/url/latest/Url#percentEncode
    Url.Builder.crossOrigin "http://localhost:8000"
        ("api" :: paths)
        queryParams
        |> Endpoint



-- Endpoint


login : Endpoint
login =
    url [ "auth", "login" ] []


entry : Endpoint
entry =
    url [ "entry" ] []


entryId : Int -> Endpoint
entryId id =
    url [ "entry", String.fromInt id ] []


week : Int -> Int -> Endpoint
week year calenderWeek =
    url [ "entry", String.fromInt year, String.fromInt calenderWeek ] []
