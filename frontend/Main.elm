module Main exposing (main)

import Api exposing (Cred)
import Avatar exposing (Avatar)
import Bootstrap.Navbar as Navbar
import Browser exposing (Document)
import Browser.Navigation as Nav
import Html exposing (..)
import Json.Decode as Decode exposing (Value)
import Page
import Page.Blank as Blank
import Page.Entry as Entry
import Page.Home as Home
import Page.Login as Login
import Page.NotFound as NotFound
import Route exposing (Route)
import Session exposing (Session)
import Task
import Time
import Url exposing (Url)
import Username exposing (Username)
import Viewer exposing (Viewer)



-- NOTE: Based on discussions around how asset management features
-- like code splitting and lazy loading have been shaping up, it's possible
-- that most of this file may become unnecessary in a future release of Elm.
-- Avoid putting things in this module unless there is no alternative!
-- See https://discourse.elm-lang.org/t/elm-spa-in-0-19/1800/2 for more.


type Model
    = Redirect Session
    | NotFound Session
    | Home Home.Model
    | Login Login.Model
    | Entry Entry.Model



-- MODEL


init : Maybe Viewer -> Url -> Nav.Key -> ( Model, Cmd Msg )
init maybeViewer url navKey =
    let
        ( navbarState, navbarCmd ) =
            Navbar.initialState GotNavbar

        ( model, msg ) =
            changeRouteTo (Route.fromUrl url)
                (Redirect (Session.fromViewer navbarState navKey maybeViewer))
    in
    ( model
    , Cmd.batch [ msg, navbarCmd ]
    )



-- VIEW


view : Model -> Document Msg
view model =
    let
        viewer =
            Session.viewer (toSession model)

        navbarState =
            Session.navState <| toSession model

        viewPage toMsg config =
            let
                { title, body } =
                    Page.view config
            in
            { title = title
            , body = Page.viewHeader GotNavbar navbarState viewer :: List.map (Html.map toMsg) body
            }
    in
    case model of
        Redirect _ ->
            Page.view Blank.view

        NotFound _ ->
            Page.view NotFound.view

        Home home ->
            viewPage GotHomeMsg (Home.view home)

        Login login ->
            viewPage GotLoginMsg (Login.view login)

        Entry entry ->
            viewPage GotEntryMsg (Entry.view entry)



-- UPDATE


type Msg
    = ChangedUrl Url
    | ClickedLink Browser.UrlRequest
    | GotHomeMsg Home.Msg
    | GotLoginMsg Login.Msg
    | GotEntryMsg Entry.Msg
    | GotSession Session
    | GotNavbar Navbar.State


toSession : Model -> Session
toSession page =
    case page of
        Redirect session ->
            session

        NotFound session ->
            session

        Home home ->
            Home.toSession home

        Login login ->
            Login.toSession login

        Entry entry ->
            Entry.toSession entry


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            toSession model
    in
    case maybeRoute of
        Nothing ->
            ( NotFound session, Cmd.none )

        Just Route.Root ->
            ( model, Route.replaceUrl (Session.navKey session) Route.Home )

        Just Route.Logout ->
            ( model, Api.logout )

        Just Route.Home ->
            Home.init session
                |> updateWith Home GotHomeMsg model

        Just Route.Login ->
            Login.init session
                |> updateWith Login GotLoginMsg model

        Just Route.Entry ->
            Entry.init session
                |> updateWith Entry GotEntryMsg model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( ClickedLink urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    case url.fragment of
                        Nothing ->
                            -- If we got a link that didn't include a fragment,
                            -- it's from one of those (href "") attributes that
                            -- we have to include to make the RealWorld CSS work.
                            --
                            -- In an application doing path routing instead of
                            -- fragment-based routing, this entire
                            -- `case url.fragment of` expression this comment
                            -- is inside would be unnecessary.
                            ( model, Cmd.none )

                        Just _ ->
                            ( model
                            , Nav.pushUrl (Session.navKey (toSession model)) (Url.toString url)
                            )

                Browser.External href ->
                    ( model
                    , Nav.load href
                    )

        ( ChangedUrl url, _ ) ->
            changeRouteTo (Route.fromUrl url) model

        ( GotLoginMsg subMsg, Login login ) ->
            Login.update subMsg login
                |> updateWith Login GotLoginMsg model

        ( GotHomeMsg subMsg, Home home ) ->
            Home.update subMsg home
                |> updateWith Home GotHomeMsg model

        ( GotEntryMsg subMsg, Entry entry ) ->
            Entry.update subMsg entry
                |> updateWith Entry GotEntryMsg model

        ( GotSession session, Redirect _ ) ->
            ( Redirect session
            , Route.replaceUrl (Session.navKey session) Route.Home
            )

        ( GotNavbar state, _ ) ->
            ( updateNavbarState state model
            , Cmd.none
            )

        ( _, _ ) ->
            -- Disregard messages that arrived for the wrong page.
            ( model, Cmd.none )


updateWith : (subModel -> Model) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )


updateNavbarState : Navbar.State -> Model -> Model
updateNavbarState state model =
    let
        updatedSession session =
            Session.changeNavState state session
    in
    case model of
        Redirect session ->
            Redirect <| updatedSession session

        NotFound session ->
            NotFound <| updatedSession session

        Home home ->
            Home (Home.updateSession (updatedSession (Home.toSession home)) home)

        Login login ->
            Login (Login.updateSession (updatedSession (Login.toSession login)) login)

        Entry entry ->
            Entry (Entry.updateSession (updatedSession (Entry.toSession entry)) entry)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ case model of
            NotFound _ ->
                Sub.none

            Redirect _ ->
                Session.changes GotSession (Session.navState (toSession model)) (Session.navKey (toSession model))

            Home home ->
                Sub.map GotHomeMsg (Home.subscriptions home)

            Login login ->
                Sub.map GotLoginMsg (Login.subscriptions login)

            Entry entry ->
                Sub.map GotEntryMsg (Entry.subscriptions entry)
        , Navbar.subscriptions (Session.navState (toSession model)) GotNavbar
        ]



-- MAIN


main : Program Value Model Msg
main =
    Api.application Viewer.decoder
        { init = init
        , onUrlChange = ChangedUrl
        , onUrlRequest = ClickedLink
        , subscriptions = subscriptions
        , update = update
        , view = view
        }
