module Main exposing (Model(..), Msg(..), init, main, subscriptions, update, view)

import Bootstrap.Button as Button
import Bootstrap.Form.Input as Input
import Bootstrap.Form.InputGroup as InputGroup
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.ListGroup as ListGroup
import Bootstrap.Utilities.Spacing as Spacing
import Browser
import Html exposing (Html, div, node, pre, text)
import Html.Attributes exposing (class, href, rel)
import Http
import Json.Decode exposing (Decoder, andThen, field, int, list, map5, string)
import Json.Decode.Extra exposing (fromResult)
import Json.Encode as Encode
import List exposing (foldl, length, map)



-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type Model
    = Failure
    | Loading
    | Success (List Entry)


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading
    , Http.get
        { url = "/api/entry"
        , expect = Http.expectJson GotEntry (list entryDecoder)
        }
    )



-- UPDATE


type Msg
    = GotEntry (Result Http.Error (List Entry))
    | Add
    | GotAdd (Result Http.Error Int)
    | Remove Int
    | Removed (Result Http.Error ())


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case Debug.log "" msg of
        GotEntry result ->
            case result of
                Ok entry ->
                    ( Success entry, Cmd.none )

                Err _ ->
                    ( Failure, Cmd.none )

        Add ->
            ( model
            , Http.post
                { url = "/api/entry"
                , expect = Http.expectJson GotAdd int
                , body = entryEncoder (Entry 0 "" Work "2019-10-10" 0) |> Encode.encode 0 |> Http.stringBody "application/json"
                }
            )

        GotAdd result ->
            updateWith model
                (\entries -> ( entries ++ [ Entry 0 "" Work "" 0 ] |> Success, Cmd.none ))

        Remove id ->
            case model of
                Success entries ->
                    ( List.filter (\entry -> entry.id /= id) entries |> Success
                    , Http.request
                        { method = "DELETE"
                        , headers = []
                        , url = "/api/entry/" ++ String.fromInt id
                        , body = Http.emptyBody
                        , expect = Http.expectWhatever Removed
                        , timeout = Nothing
                        , tracker = Nothing
                        }
                    )

                _ ->
                    ( model, Cmd.none )

        Removed _ ->
            ( model, Cmd.none )


updateWith : Model -> (List Entry -> ( Model, Cmd Msg )) -> ( Model, Cmd Msg )
updateWith model transformer =
    case model of
        Success entries ->
            transformer entries

        _ ->
            ( Failure, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    Grid.container []
        [ node "link"
            [ rel "stylesheet"
            , href "/static/css/bootstrap.min.css"
            ]
            []
        , case model of
            Failure ->
                text "I was unable to load the entries."

            Loading ->
                text "Loading..."

            Success entry ->
                div []
                    [ Button.button [ Button.success, Button.block, Button.attrs [ Spacing.mb3 ], Button.onClick Add ] [ text "Add new" ]
                    , ListGroup.ul
                        (List.map (\e -> ListGroup.li [] [ viewEntry e ]) entry)
                    ]
        ]


viewEntry : Entry -> Html Msg
viewEntry entry =
    let
        viewEntryField space field =
            Grid.col [ space ]
                [ InputGroup.config
                    (InputGroup.text [ field ])
                    |> InputGroup.attrs [ Spacing.mb3 ]
                    |> InputGroup.view
                ]
    in
    div []
        [ Grid.row []
            [ viewEntryField Col.xs10 (Input.value entry.title)
            , viewEntryField Col.xs2 (Input.value entry.logdate)
            ]
        , Grid.row []
            [ viewEntryField Col.xs3 (Input.value (entryTypeToString entry.entryType))
            , Grid.col [ Col.xs7 ] []
            , viewEntryField Col.xs2 (Input.value (String.fromInt entry.spendTime))
            ]
        , Button.button [ Button.danger, Button.block, Button.onClick (Remove entry.id) ] [ text "Delete" ]
        ]


type alias Entry =
    { id : Int
    , title : String
    , entryType : EntryType
    , logdate : String
    , spendTime : Int
    }


type EntryType
    = Work
    | School
    | Training


entryDecoder : Decoder Entry
entryDecoder =
    map5 Entry
        (field "id" int)
        (field "title" string)
        (field "entry_type" entryTypeDecoder)
        (field "logdate" string)
        (field "spend_time" int)


entryTypeToString : EntryType -> String
entryTypeToString entryType =
    case entryType of
        Work ->
            "Betriebliche Tätigkeit"

        School ->
            "Berufsschule"

        Training ->
            "Schulung"


entryTypeDecoder : Decoder EntryType
entryTypeDecoder =
    let
        decodeToType string =
            case string of
                "Betriebliche Tätigkeit" ->
                    Result.Ok Work

                "Berufsschule" ->
                    Result.Ok School

                "Schulung" ->
                    Result.Ok Training

                _ ->
                    Result.Err ("Not valid pattern for decoder to Suit. Pattern: " ++ string)
    in
    string |> andThen (decodeToType >> fromResult)


entryEncoder : Entry -> Encode.Value
entryEncoder entry =
    Encode.object
        [ ( "id", Encode.int entry.id )
        , ( "title", Encode.string entry.title )
        , ( "entry_type", entryTypeToString entry.entryType |> Encode.string )
        , ( "logdate", Encode.string entry.logdate )
        , ( "spend_time", Encode.int entry.spendTime )
        ]
