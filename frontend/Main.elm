module Main exposing (Model(..), Msg(..), init, main, subscriptions, update, view)

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
import Entry
import Html exposing (Html, div, node, pre, text)
import Html.Attributes as Attributes exposing (class, href, rel)
import Http
import Json.Decode exposing (Decoder, andThen, field, int, list, map5, string)
import Json.Decode.Extra exposing (fromResult)
import Json.Encode as Encode
import List exposing (foldl, length, map)
import Maybe
import Task
import Time exposing (Month(..), Weekday(..))
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


type Model
    = Entry Entry.Model


init : () -> ( Model, Cmd Msg )
init _ =
    ( { entries = []
      , modalEdit = ( Modal.hidden, Entry.emptyEntry )
      , today = Date.fromCalendarDate 2019 Jan 1
      , weekNumberFilter = 0
      }
    , Cmd.batch
        [ Http.get
            { url = "/api/entry"
            , expect = Http.expectJson Entry.GotEntry (list Entry.entryDecoder)
            }
        , Task.perform Entry.ReceiveDate Date.today
        ]
    )
        |> updateWith Entry GotEntryMsg



-- UPDATE


type Msg
    = GotEntryMsg Entry.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( GotEntryMsg subMsg, Entry entry ) ->
            Entry.update subMsg entry
                |> updateWith Entry GotEntryMsg


updateWith : (subModel -> Model) -> (subMsg -> Msg) -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    let
        viewPage toMsg subMsg =
            Html.map toMsg subMsg
    in
    Grid.containerFluid []
        [ node "link"
            [ rel "stylesheet"
            , href "/static/css/bootstrap.min.css"
            ]
            []
        , case model of
            Entry entry ->
                viewPage GotEntryMsg <| Entry.view entry
        ]
