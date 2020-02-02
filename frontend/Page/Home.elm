module Page.Home exposing (Model, Msg, init, subscriptions, update, view)

{-| The homepage. You can get here via either the / or /#/ routes.
-}

import Api exposing (Cred)
import Api.Endpoint as Endpoint
import Browser.Dom as Dom
import Html exposing (..)
import Html.Attributes exposing (attribute, class, classList, href, id, placeholder)
import Html.Events exposing (onClick)
import Http
import Page
import Session exposing (Session)
import Task exposing (Task)
import Time
import Url.Builder
import Username exposing (Username)
import Viewer exposing (Viewer)



-- MODEL


type alias Model =
    {}


init : Viewer -> ( Model, Cmd Msg )
init _ =
    ( {}, Cmd.none )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "Home"
    , content =
        text "Hello there"
    }



-- UPDATE


type Msg
    = DummyMsg


update : Msg -> Model -> Viewer -> ( Model, Cmd Msg )
update msg model _ =
    case msg of
        DummyMsg ->
            ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
