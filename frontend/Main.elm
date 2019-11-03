module Main exposing (Entry, EntryType(..), Model, Msg(..), entryDecoder, entryEncoder, entryTypeDecoder, entryTypeToString, init, main, subscriptions, update, updateEntries, view, viewEntry)

import Bootstrap.Button as Button
import Bootstrap.ButtonGroup as ButtonGroup
import Bootstrap.Form.Input as Input
import Bootstrap.Form.InputGroup as InputGroup
import Bootstrap.General.HAlign as HAlign
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.ListGroup as ListGroup
import Bootstrap.Modal as Modal
import Bootstrap.Utilities.Display as Display
import Bootstrap.Utilities.Spacing as Spacing
import Browser
import Date
import Html exposing (Html, div, node, pre, text)
import Html.Attributes exposing (class, href, rel)
import Http
import Json.Decode exposing (Decoder, andThen, field, int, list, map5, string)
import Json.Decode.Extra exposing (fromResult)
import Json.Encode as Encode
import List exposing (foldl, length, map)
import Maybe
import Task
import Time exposing (Month(..))
import Tuple



-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Model =
    { entries : List Entry
    , modalEdit : ( Modal.Visibility, Entry )
    , today : Date.Date
    , weekNumberFilter : Int
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { entries = []
      , modalEdit = ( Modal.hidden, emptyEntry )
      , today = Date.fromCalendarDate 2019 Jan 1
      , weekNumberFilter = 0
      }
    , Cmd.batch
        [ Http.get
            { url = "/api/entry"
            , expect = Http.expectJson GotEntry (list entryDecoder)
            }
        , Date.today |> Task.perform ReceiveDate
        ]
    )



-- UPDATE


type Msg
    = GotEntry (Result Http.Error (List Entry))
    | Add
    | GotAdd (Result Http.Error Int)
    | Remove Int
    | Removed (Result Http.Error ())
    | ShowEdit Entry
    | SaveEntry Entry
    | CloseEdit (Result Http.Error ())
    | EditEntry EditMsg Entry String
    | ReceiveDate Date.Date
    | Filter String


type EditMsg
    = Title
    | Type EntryType
    | Logdate
    | SpendTime


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        newWithId m id =
            Entry id "" Work (Date.format "yyyy-MM-dd" m.today) 0
    in
    case Debug.log "" msg of
        GotEntry result ->
            case result of
                Ok entry ->
                    ( updateEntries model (\_ -> entry), Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        Add ->
            ( model
            , Http.post
                { url = "/api/entry"
                , expect = Http.expectJson GotAdd int
                , body = entryEncoder (newWithId model 0) |> Encode.encode 0 |> Http.stringBody "application/json"
                }
            )

        GotAdd result ->
            case result of
                Ok id ->
                    updateEntries model
                        (\entries -> entries ++ [ newWithId model id ])
                        |> update (ShowEdit (newWithId model id))

                Err _ ->
                    ( model, Cmd.none )

        Remove id ->
            ( updateEntries model (\entries -> List.filter (\entry -> entry.id /= id) entries)
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

        Removed _ ->
            ( model, Cmd.none )

        ShowEdit entry ->
            ( { model | modalEdit = ( Modal.shown, entry ) }, Cmd.none )

        CloseEdit entry ->
            ( { model | modalEdit = ( Modal.hidden, emptyEntry ) }, Cmd.none )

        SaveEntry entry ->
            ( updateEntries model
                (\entries ->
                    List.map
                        (\e ->
                            if e.id == entry.id then
                                entry

                            else
                                e
                        )
                        entries
                )
            , Http.request
                { method = "PUT"
                , headers = []
                , url = "/api/entry/" ++ String.fromInt entry.id
                , body = entryEncoder entry |> Encode.encode 0 |> Http.stringBody "application/json"
                , expect = Http.expectWhatever CloseEdit
                , timeout = Nothing
                , tracker = Nothing
                }
            )

        EditEntry kind entry value ->
            let
                updateEntry k e v =
                    case k of
                        Title ->
                            { e | title = v }

                        Type new ->
                            { e | entryType = new }

                        Logdate ->
                            { e | logdate = v }

                        SpendTime ->
                            { e | spendTime = Maybe.withDefault 0 (String.toInt v) }
            in
            ( { model
                | modalEdit = ( Tuple.first model.modalEdit, updateEntry kind entry value )
              }
            , Cmd.none
            )

        ReceiveDate date ->
            ( { model | today = date }, Cmd.none )

        Filter weekNumber ->
            ( { model | weekNumberFilter = Maybe.withDefault 0 (String.toInt weekNumber) }
            , Http.get
                { url = "/api/entry/" ++ String.fromInt 2019 ++ "/" ++ weekNumber
                , expect = Http.expectJson GotEntry (list entryDecoder)
                }
            )


updateEntries : Model -> (List Entry -> List Entry) -> Model
updateEntries model transformer =
    { model | entries = transformer model.entries }



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
        , div []
            [ Button.button [ Button.success, Button.block, Button.attrs [ Spacing.mb3 ], Button.onClick Add ] [ text "Add new" ]
            , InputGroup.config (InputGroup.number [ Input.value (String.fromInt model.weekNumberFilter), Input.onInput Filter ]) |> InputGroup.view
            , ListGroup.ul
                (List.map (\e -> ListGroup.li [] [ viewEntry e ]) model.entries)
            ]
        , editModal model.modalEdit
        ]


viewEntry : Entry -> Html Msg
viewEntry entry =
    let
        viewEntryField space field =
            Grid.col [ space ]
                [ div [ Spacing.mb3 ] [ text field ]
                ]
    in
    div []
        [ Grid.row []
            [ viewEntryField Col.xs10 entry.title
            , viewEntryField Col.xs2 entry.logdate
            ]
        , Grid.row []
            [ viewEntryField Col.xs3 (entryTypeToString entry.entryType)
            , Grid.col [ Col.xs7 ] []
            , viewEntryField Col.xs2 (String.fromInt entry.spendTime)
            ]
        , ButtonGroup.buttonGroup []
            [ ButtonGroup.button [ Button.primary, Button.onClick (ShowEdit entry) ] [ text "Edit" ]
            , ButtonGroup.button [ Button.danger, Button.onClick (Remove entry.id) ] [ text "Delete" ]
            ]
        ]


editModal : ( Modal.Visibility, Entry ) -> Html Msg
editModal option =
    let
        visibility =
            Tuple.first option

        entry =
            Tuple.second option

        viewEntryField kind attrs =
            InputGroup.config
                (kind attrs)
                |> InputGroup.attrs [ Spacing.mb3 ]
                |> InputGroup.view

        radio entryType =
            ButtonGroup.radioButton
                (entry.entryType == entryType)
                [ Button.primary, Button.onClick (EditEntry (Type entryType) entry "") ]
                [ entryTypeToString entryType |> text ]
    in
    div []
        [ Modal.config (CloseEdit (Result.Ok ()))
            |> Modal.hideOnBackdropClick True
            |> Modal.h3 [] [ text "Edit Entry" ]
            |> Modal.body []
                [ viewEntryField InputGroup.text
                    [ Input.value entry.title
                    , Input.onInput (EditEntry Title entry)
                    ]
                , viewEntryField InputGroup.date
                    [ Input.value entry.logdate
                    , Input.onInput (EditEntry Logdate entry)
                    ]
                , ButtonGroup.radioButtonGroup [ ButtonGroup.attrs [ Spacing.mb3 ] ]
                    [ radio Work
                    , radio School
                    , radio Training
                    ]
                , viewEntryField InputGroup.number
                    [ Input.value (String.fromInt entry.spendTime)
                    , Input.onInput (EditEntry SpendTime entry)
                    ]
                ]
            |> Modal.footer []
                [ Button.button [ Button.outlinePrimary, Button.onClick (SaveEntry entry) ] [ text "Save" ] ]
            |> Modal.view visibility
        ]



-- viewEntry : Entry -> Html Msg
-- viewEntry entry =
--     let
--         viewEntryField space kind field =
--             Grid.col [ space ]
--                 [ InputGroup.config
--                     (kind [ field ])
--                     |> InputGroup.attrs [ Spacing.mb3 ]
--                     |> InputGroup.view
--                 ]
--     in
--     div []
--         [ Grid.row []
--             [ viewEntryField Col.xs10 InputGroup.text (Input.value entry.title)
--             , viewEntryField Col.xs2 InputGroup.date (Input.value entry.logdate)
--             ]
--         , Grid.row []
--             [ viewEntryField Col.xs3 InputGroup.text (Input.value (entryTypeToString entry.entryType))
--             , Grid.col [ Col.xs7 ] []
--             , viewEntryField Col.xs2 InputGroup.number (Input.value (String.fromInt entry.spendTime))
--             ]
--         , Button.button [ Button.danger, Button.block, Button.onClick (Remove entry.id) ] [ text "Delete" ]
--         ]


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


emptyEntry : Entry
emptyEntry =
    Entry 0 "" Work "" 0


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
