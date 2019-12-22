module Page.Entry exposing (Entry, Model, Msg(..), emptyEntry, entryDecoder, toSession, update, view)

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
import Html.Attributes as Attributes exposing (class, href, rel)
import Http
import Json.Decode exposing (Decoder, andThen, field, int, list, map5, string)
import Json.Decode.Extra exposing (fromResult)
import Json.Encode as Encode
import List exposing (foldl, length, map)
import Maybe
import Session exposing (Session)
import Task
import Time exposing (Month(..), Weekday(..))
import Tuple



-- MODEL


type alias Model =
    { session : Session
    , entries : List Entry
    , modalEdit : ( Modal.Visibility, Entry )
    , today : Date.Date
    , weekNumberFilter : Int
    }



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
            Entry id "" Work m.today 0
    in
    case msg of
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

                        Type t ->
                            { e | entryType = t }

                        Logdate ->
                            { e | logdate = Result.withDefault entry.logdate (Date.fromIsoString v) }

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



-- VIEW


view : Model -> Html Msg
view model =
    let
        numberField option description =
            InputGroup.config
                (InputGroup.number option)
                |> InputGroup.predecessors [ InputGroup.span [] [ text description ] ]
                |> InputGroup.view

        totalHours =
            List.foldl (\e acc -> acc + e.spendTime) 0 model.entries
    in
    div []
        [ div []
            [ Grid.row [ Row.attrs [ Spacing.mt3 ] ]
                (List.map (\e -> Grid.col [ Col.attrs [ Spacing.mb3 ] ] [ e ])
                    [ Button.button [ Button.success, Button.block, Button.attrs [ Spacing.mb3 ], Button.onClick Add ] [ text "Neu" ]
                    , numberField
                        [ Input.value (String.fromInt model.weekNumberFilter), Input.onInput Filter ]
                        "Kalenderwoche"
                    , numberField
                        [ Input.value (totalHours |> String.fromInt)
                        , Input.disabled True
                        ]
                        "Gesamt"
                    , numberField
                        [ Input.value (40 - totalHours |> String.fromInt)
                        , Input.disabled True
                        ]
                        "Fehlend"
                    ]
                )
            , Grid.row []
                (List.map
                    (\t ->
                        Grid.col []
                            [ ListGroup.ul
                                (ListGroup.li [ ListGroup.info ] [ entryTypeToString t |> text ]
                                    :: List.map
                                        (\e -> ListGroup.li [] [ viewEntry e ])
                                        (List.filter (\entry -> entry.entryType == t) model.entries)
                                )
                            ]
                    )
                    [ Work, Training, School ]
                )
            , editModal model.modalEdit
            ]
        ]


viewEntry : Entry -> Html Msg
viewEntry entry =
    let
        viewEntryField space field =
            Grid.col [ space ]
                [ div [ Spacing.mb3 ] [ text field ]
                ]

        weekdayToString weekday =
            case weekday of
                Mon ->
                    "Montag"

                Tue ->
                    "Dienstag"

                Wed ->
                    "Mittwoch"

                Thu ->
                    "Donerstag"

                Fri ->
                    "Freitag"

                Sat ->
                    "Samstag"

                Sun ->
                    "Sonntag"
    in
    div []
        [ Grid.row []
            [ viewEntryField Col.xs11 entry.title
            , viewEntryField Col.xs1 (String.fromInt entry.spendTime)
            ]
        , Grid.row []
            [ Grid.col []
                [ ButtonGroup.buttonGroup []
                    [ ButtonGroup.button [ Button.primary, Button.onClick (ShowEdit entry) ] [ text "Bearbeiten" ]
                    , ButtonGroup.button [ Button.danger, Button.onClick (Remove entry.id) ] [ text "Löschen" ]
                    ]
                ]
            , viewEntryField Col.xs2 (Date.weekday entry.logdate |> weekdayToString)
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
                    [ Input.value (Date.toIsoString entry.logdate)
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


type alias Entry =
    { id : Int
    , title : String
    , entryType : EntryType
    , logdate : Date.Date
    , spendTime : Int
    }


type EntryType
    = Work
    | School
    | Training


emptyEntry : Entry
emptyEntry =
    Entry 0 "" Work (Date.fromCalendarDate 1970 Jan 1) 0


entryDecoder : Decoder Entry
entryDecoder =
    map5 Entry
        (field "id" int)
        (field "title" string)
        (field "entry_type" entryTypeDecoder)
        (field "logdate" string |> andThen (Date.fromIsoString >> fromResult))
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
        , ( "logdate", Encode.string (Date.format "yyyy-MM-dd" entry.logdate) )
        , ( "spend_time", Encode.int entry.spendTime )
        ]



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
