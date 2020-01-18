module Page.Entry exposing (Model, Msg(..), emptyEntry, init, subscriptions, toSession, update, updateSession, view)

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



-- MODEL


type alias Model =
    { session : Session
    , entries : List Entry
    , modalEdit : ( Modal.Visibility, Entry )
    , today : Posix
    , zone : Zone
    , weekNumberFilter : Int
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , entries = []
      , modalEdit = ( Modal.hidden, emptyEntry )
      , today = Time.millisToPosix 0
      , zone = Time.utc
      , weekNumberFilter = 0
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = CompletedLoadEntries (Api.Response (List Entry))
    | CompletedSave (Api.Response ())
    | Add Cred
    | GotAdd (Api.Response Int)
    | Remove Cred Entry
    | Removed (Api.Response ())
    | ShowEdit Entry
    | SaveEntry Cred Entry
    | CloseEdit
    | EditEntry EditMsg Entry String
    | GotTime Posix
    | Filter Cred String
    | GotSession Session


type EditMsg
    = Title
    | Type EntryType
    | Logdate
    | SpendTime


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        newWithId id =
            Entry id "" Work model.today 0
    in
    case msg of
        CompletedLoadEntries (Ok entry) ->
            ( updateEntries model (\_ -> entry |> Tuple.second), Cmd.none )

        CompletedLoadEntries (Err _) ->
            ( model, Cmd.none )

        Add cred ->
            ( model
            , add emptyEntry cred GotAdd
            )

        GotAdd (Ok ( _, id )) ->
            updateEntries model
                (\entries -> entries ++ [ newWithId id ])
                |> update (ShowEdit (newWithId id))

        GotAdd (Err _) ->
            ( model, Cmd.none )

        Remove cred entry ->
            ( updateEntries model (\entries -> List.filter (\e -> e.id /= entry.id) entries)
            , delete entry cred Removed
            )

        Removed _ ->
            ( model, Cmd.none )

        ShowEdit entry ->
            ( { model | modalEdit = ( Modal.shown, entry ) }, Cmd.none )

        CloseEdit ->
            ( { model | modalEdit = ( Modal.hidden, emptyEntry ) }, Cmd.none )

        SaveEntry cred entry ->
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
            , Entry.update entry cred CompletedSave
            )

        CompletedSave _ ->
            ( closeModelEdit model, Cmd.none )

        EditEntry kind entry value ->
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

        GotTime date ->
            ( { model | today = date }, Cmd.none )

        Filter cred weekNumber ->
            let
                value =
                    Maybe.withDefault 0 (String.toInt weekNumber)
            in
            ( { model | weekNumberFilter = value }
            , Entry.fetch 2020 value cred CompletedLoadEntries
            )

        GotSession session ->
            ( { model | session = session }, Cmd.none )


closeModelEdit : Model -> Model
closeModelEdit model =
    { model | modalEdit = ( Modal.hidden, emptyEntry ) }


updateSession : Session -> Model -> Model
updateSession session model =
    { model | session = session }


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

        maybeCred =
            Session.cred model.session
    in
    { title = "Entry"
    , content =
        case maybeCred of
            Just cred ->
                div []
                    [ div []
                        [ Grid.row [ Row.attrs [ Spacing.mt3 ] ]
                            (List.map (\e -> Grid.col [ Col.attrs [ Spacing.mb3 ] ] [ e ])
                                [ Button.button [ Button.success, Button.block, Button.attrs [ Spacing.mb3 ], Button.onClick (Add cred) ] [ text "Neu" ]
                                , numberField
                                    [ Input.value (String.fromInt model.weekNumberFilter), Input.onInput (Filter cred) ]
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
                                                    (\e -> ListGroup.li [] [ viewEntry cred model.zone e ])
                                                    (List.filter (\entry -> entry.entryType == t) model.entries)
                                            )
                                        ]
                                )
                                [ Work, Training, School ]
                            )
                        , editModal cred model.modalEdit
                        ]
                    ]

            Nothing ->
                div [] []
    }


viewEntry : Cred -> Zone -> Entry -> Html Msg
viewEntry cred zone entry =
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
                    , ButtonGroup.button [ Button.danger, Button.onClick (Remove cred entry) ] [ text "Löschen" ]
                    ]
                ]
            , viewEntryField Col.xs2 (Time.toWeekday zone entry.logdate |> weekdayToString)
            ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Session.changes GotSession (Session.navState model.session) (Session.navKey model.session)


editModal : Cred -> ( Modal.Visibility, Entry ) -> Html Msg
editModal cred option =
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
        [ Modal.config CloseEdit
            |> Modal.hideOnBackdropClick True
            |> Modal.h3 [] [ text "Edit Entry" ]
            |> Modal.body []
                [ viewEntryField InputGroup.text
                    [ Input.value entry.title
                    , Input.onInput (EditEntry Title entry)
                    ]
                , viewEntryField InputGroup.date
                    [ Input.value (Iso8601.fromTime entry.logdate)
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
                [ Button.button [ Button.outlinePrimary, Button.onClick (SaveEntry cred entry) ] [ text "Save" ] ]
            |> Modal.view visibility
        ]


emptyEntry : Entry
emptyEntry =
    Entry 0 "" Work (Time.millisToPosix 0) 0



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
