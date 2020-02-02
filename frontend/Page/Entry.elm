module Page.Entry exposing (Model, Msg(..), emptyEntry, init, subscriptions, update, view)

import Api exposing (Cred)
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
import DateFormat
import Entry exposing (..)
import Html exposing (Html, div, node, pre, text)
import Html.Attributes as Attributes exposing (class, href, rel)
import Http
import Iso8601
import Json.Decode exposing (Decoder, andThen, field, int, list, map5, string)
import Json.Decode.Extra exposing (fromResult)
import Json.Encode as Encode
import List exposing (foldl, length, map)
import Maybe
import Session exposing (Session)
import Task
import Time exposing (Month(..), Posix, Weekday(..), Zone)
import Tuple
import Viewer exposing (Viewer)



-- MODEL


type alias Model =
    { entries : List Entry
    , modalEdit : ( Modal.Visibility, Entry )
    , today : Posix
    , zone : Zone
    , weekNumberFilter : Int
    }


init : Viewer -> ( Model, Cmd Msg )
init _ =
    ( { entries = []
      , modalEdit = ( Modal.hidden, emptyEntry )
      , today = Time.millisToPosix 0
      , zone = Time.utc
      , weekNumberFilter = 0
      }
    , Cmd.batch
        [ Task.perform GotZone Time.here
        , Task.perform GotTime Time.now
        ]
    )



-- UPDATE


type Msg
    = CompletedLoadEntries (Api.Response (List Entry))
    | CompletedSaveEntry Api.WhateverResponse
    | CompletedNewEntry (Api.Response Int)
    | CompletedRemoveEntry Api.WhateverResponse
    | ClickedNewEntry
    | ClickedRemoveEntry Entry
    | ClickedShowEdit Entry
    | ClickedSaveEntry Entry
    | ClickedCloseEdit
    | ClickedEditEntry EditMsg Entry String
    | ChangedFilter String
    | GotTime Posix
    | GotZone Zone


type EditMsg
    = Title
    | Type EntryType
    | Logdate
    | SpendTime


update : Msg -> Model -> Viewer -> ( Model, Cmd Msg )
update msg model viewer =
    let
        newWithId id =
            Entry id "" Work model.today 0

        cred =
            Viewer.cred viewer
    in
    case msg of
        CompletedLoadEntries (Ok entry) ->
            ( updateEntries model (\_ -> entry |> Tuple.second), Cmd.none )

        CompletedLoadEntries (Err _) ->
            ( model, Cmd.none )

        CompletedSaveEntry _ ->
            ( closeModelEdit model, Cmd.none )

        CompletedNewEntry (Ok ( _, id )) ->
            ( updateEntries { model | modalEdit = ( Modal.shown, newWithId id ) }
                (\entries -> entries ++ [ newWithId id ])
            , Cmd.none
            )

        CompletedNewEntry (Err _) ->
            ( model, Cmd.none )

        CompletedRemoveEntry _ ->
            ( model, Cmd.none )

        ClickedShowEdit entry ->
            ( { model | modalEdit = ( Modal.shown, entry ) }, Cmd.none )

        ClickedSaveEntry entry ->
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
            , Entry.update entry cred CompletedSaveEntry
            )

        ClickedCloseEdit ->
            ( { model | modalEdit = ( Modal.hidden, emptyEntry ) }, Cmd.none )

        ClickedNewEntry ->
            ( model
            , add (newWithId 0) cred CompletedNewEntry
            )

        ClickedRemoveEntry entry ->
            ( updateEntries model (\entries -> List.filter (\e -> e.id /= entry.id) entries)
            , delete entry cred CompletedRemoveEntry
            )

        ClickedEditEntry kind entry value ->
            let
                updateEntry k e v =
                    case k of
                        Title ->
                            { e | title = v }

                        Type t ->
                            { e | entryType = t }

                        Logdate ->
                            { e | logdate = Result.withDefault entry.logdate (Iso8601.toTime v) }

                        SpendTime ->
                            { e | spendTime = Maybe.withDefault 0 (String.toInt v) }
            in
            ( { model
                | modalEdit = ( Tuple.first model.modalEdit, updateEntry kind entry value )
              }
            , Cmd.none
            )

        ChangedFilter weekNumber ->
            let
                value =
                    Maybe.withDefault 0 (String.toInt weekNumber)
            in
            ( { model | weekNumberFilter = value }
            , Entry.fetch 2020 value cred CompletedLoadEntries
            )

        GotTime date ->
            ( { model | today = date, weekNumberFilter = String.toInt (DateFormat.format [ DateFormat.weekOfYearNumber ] model.zone date) |> Maybe.withDefault 0 }, Cmd.none )

        GotZone zone ->
            ( { model | zone = zone }, Cmd.none )


closeModelEdit : Model -> Model
closeModelEdit model =
    { model | modalEdit = ( Modal.hidden, emptyEntry ) }


updateEntries : Model -> (List Entry -> List Entry) -> Model
updateEntries model transformer =
    { model | entries = transformer model.entries }



-- VIEW


view : Model -> { title : String, content : Html Msg }
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
    { title = "Entry"
    , content =
        div []
            [ div []
                [ Grid.row [ Row.attrs [ Spacing.mt3 ] ]
                    (List.map (\e -> Grid.col [ Col.attrs [ Spacing.mb3 ] ] [ e ])
                        [ Button.button [ Button.success, Button.block, Button.attrs [ Spacing.mb3 ], Button.onClick ClickedNewEntry ] [ text "Neu" ]
                        , numberField
                            [ Input.value (String.fromInt model.weekNumberFilter), Input.onInput ChangedFilter ]
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
                                            (\e -> ListGroup.li [] [ viewEntry model.zone e ])
                                            (List.filter (\entry -> entry.entryType == t) model.entries)
                                    )
                                ]
                        )
                        [ Work, Training, School ]
                    )
                , editModal model.modalEdit model.zone
                ]
            ]
    }


viewEntry : Zone -> Entry -> Html Msg
viewEntry zone entry =
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
                    [ ButtonGroup.button [ Button.primary, Button.onClick (ClickedShowEdit entry) ] [ text "Bearbeiten" ]
                    , ButtonGroup.button [ Button.danger, Button.onClick (ClickedRemoveEntry entry) ] [ text "Löschen" ]
                    ]
                ]
            , viewEntryField Col.xs2 (Time.toWeekday zone entry.logdate |> weekdayToString)
            ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


editModal : ( Modal.Visibility, Entry ) -> Zone -> Html Msg
editModal option zone =
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
                [ Button.primary, Button.onClick (ClickedEditEntry (Type entryType) entry "") ]
                [ entryTypeToString entryType |> text ]
    in
    div []
        [ Modal.config ClickedCloseEdit
            |> Modal.hideOnBackdropClick True
            |> Modal.h3 [] [ text "Edit Entry" ]
            |> Modal.body []
                [ viewEntryField InputGroup.text
                    [ Input.value entry.title
                    , Input.onInput (ClickedEditEntry Title entry)
                    ]
                , viewEntryField InputGroup.date
                    [ Input.value (Debug.log "Date" (formatDate entry.logdate zone))
                    , Input.onInput (ClickedEditEntry Logdate entry)
                    ]
                , ButtonGroup.radioButtonGroup [ ButtonGroup.attrs [ Spacing.mb3 ] ]
                    [ radio Work
                    , radio Training
                    , radio School
                    ]
                , viewEntryField InputGroup.number
                    [ Input.value (String.fromInt entry.spendTime)
                    , Input.onInput (ClickedEditEntry SpendTime entry)
                    ]
                ]
            |> Modal.footer []
                [ Button.button [ Button.outlinePrimary, Button.onClick (ClickedSaveEntry entry) ] [ text "Save" ] ]
            |> Modal.view visibility
        ]


formatDate : Posix -> Zone -> String
formatDate date zone =
    DateFormat.format
        [ DateFormat.yearNumber
        , DateFormat.text "-"
        , DateFormat.monthFixed
        , DateFormat.text "-"
        , DateFormat.dayOfMonthFixed
        ]
        zone
        date


emptyEntry : Entry
emptyEntry =
    Entry 0 "" Work (Time.millisToPosix 0) 0
