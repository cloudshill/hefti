module Main exposing (Model(..), Msg(..), init, main, subscriptions, update, view)

import Bootstrap.Grid as Grid
import Bootstrap.Modal as Modal
import Browser
import Date
import Html exposing (Html, div, node, pre, text)
import Html.Attributes as Attributes exposing (class, href, rel)
import Http
import Json.Decode exposing (Decoder, Value, andThen, field, int, list, map5, string)
import Json.Decode.Extra exposing (fromResult)
import Json.Encode as Encode
import List exposing (foldl, length, map)
import Maybe
import Page.Entry as Entry
import Session exposing (Session)
import Task
import Time exposing (Month(..), Weekday(..))
import Tuple
import Url exposing (Url)
import Viewer



-- MAIN


main : Program Value Model Msg
main =
    Api.application Viewer.decoder
        { init = init
        , onUrlChange = ChangedUrl
        , onUrlRequest = ClickedLink
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
      , session = Session.Guest
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
    = ChangedUrl Url
    | ClickedLink Browser.UrlRequest
    | GotEntryMsg Entry.Msg
    | GotSession Session


toSession : Model -> Session
toSession page =
    case page of
        Entry entry ->
            Entry.toSession entry


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        viewer =
            Session.viewer (toSession model)
    in
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
        viewer =
            Session.viewer (toSession model)

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
                viewPage GotEntryMsg (Entry.view entry)
        ]
