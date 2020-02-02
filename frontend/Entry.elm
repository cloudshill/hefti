module Entry exposing (Entry, EntryType(..), add, delete, entryTypeToString, fetch, update)

import Api exposing (Cred)
import Api.Endpoint as Endpoint
import Http
import Http.Detailed exposing (Error)
import Iso8601
import Json.Decode as Decode exposing (Decoder, andThen, field, int, map5, string)
import Json.Decode.Extra exposing (datetime, fromResult)
import Json.Encode as Encode exposing (Value)
import Result exposing (Result(..))
import Time exposing (Posix)



-- TYPES


type alias Entry =
    { id : Int
    , title : String
    , entryType : EntryType
    , logdate : Posix
    , spendTime : Int
    }


type EntryType
    = Work
    | School
    | Training



-- HTTP


fetch : Int -> Int -> Cred -> (Api.Response (List Entry) -> msg) -> Cmd msg
fetch year calenderWeek cred expect =
    Api.get (Endpoint.week year calenderWeek) (Just cred) expect (Decode.list entryDecoder)


add : Entry -> Cred -> (Api.Response Int -> msg) -> Cmd msg
add entry cred expect =
    let
        body =
            entryEncoder entry |> Http.jsonBody
    in
    Api.post Endpoint.entry (Just cred) body expect (Decode.field "id" int)


update : Entry -> Cred -> (Api.Response () -> msg) -> Cmd msg
update entry cred expect =
    Api.put (Endpoint.entryId entry.id) cred (Http.jsonBody <| entryEncoder entry) expect (Decode.succeed ())


delete : Entry -> Cred -> (Api.Response () -> msg) -> Cmd msg
delete entry cred expect =
    Api.delete (Endpoint.entryId entry.id) cred Http.emptyBody expect (Decode.succeed ())



-- ENCODERS


entryEncoder : Entry -> Value
entryEncoder entry =
    Encode.object
        [ ( "id", Encode.int entry.id )
        , ( "title", Encode.string entry.title )
        , ( "entry_type", entryTypeEncoder entry.entryType )
        , ( "logdate", Encode.int <| Time.posixToMillis entry.logdate )
        , ( "spend_time", Encode.int entry.spendTime )
        ]


entryTypeEncoder : EntryType -> Value
entryTypeEncoder entrytype =
    Encode.string
        (case entrytype of
            Work ->
                "Work"

            School ->
                "School"

            Training ->
                "Training"
        )


entryTypeToString : EntryType -> String
entryTypeToString entrytype =
    case entrytype of
        Work ->
            "Betriebliche Tätigkeit"

        School ->
            "Berufsschule"

        Training ->
            "Schulung"



-- DECODERS


entryDecoder : Decoder Entry
entryDecoder =
    map5 Entry
        (field "id" int)
        (field "title" string)
        (field "entry_type" entryTypeDecoder)
        (field "logdata" datetime)
        (field "spendtime" int)


entryTypeDecoder : Decoder EntryType
entryTypeDecoder =
    let
        decodeToType string =
            case string of
                "Work" ->
                    Ok Work

                "School" ->
                    Ok School

                "Training" ->
                    Ok Training

                _ ->
                    Err ("Not valid pattern for decoder to Suit. Pattern: " ++ string)
    in
    string |> andThen (decodeToType >> fromResult)
