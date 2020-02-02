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


type alias Model =
    { session : Session
    , pageModel : PageModel
    }


type PageModel
    = Redirect
    | NotFound
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
                { session = Session.fromViewer navbarState navKey maybeViewer
                , pageModel = Redirect
                }
    in
    ( model
    , Cmd.batch [ msg, navbarCmd ]
    )



-- VIEW


view : Model -> Document Msg
view model =
    let
        viewer =
            Session.viewer model.session

        navbarState =
            Session.navState model.session

        viewPage toMsg config =
            let
                { title, body } =
                    Page.view config
            in
            { title = title
            , body = Page.viewHeader GotNavbar navbarState viewer :: List.map (Html.map toMsg) body
            }
    in
    case model.pageModel of
        Redirect ->
            Page.view Blank.view

        NotFound ->
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


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    case Session.viewer model.session of
        Nothing ->
            case maybeRoute of
                Just Route.Login ->
                    Login.init
                        |> updateWith Login GotLoginMsg model

                Nothing ->
                    ( { model | pageModel = NotFound }, Cmd.none )

                _ ->
                    ( model, Route.replaceUrl (Session.navKey model.session) Route.Login )

        Just viewer ->
            case maybeRoute of
                Nothing ->
                    ( { model | pageModel = NotFound }, Cmd.none )

                Just Route.Root ->
                    ( model, Route.replaceUrl (Session.navKey model.session) Route.Home )

                Just Route.Logout ->
                    ( model, Api.logout )

                Just Route.Home ->
                    Home.init viewer
                        |> updateWith Home GotHomeMsg model

                Just Route.Login ->
                    Login.init
                        |> updateWith Login GotLoginMsg model

                Just Route.Entry ->
                    Entry.init viewer
                        |> updateWith Entry GotEntryMsg model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case Session.viewer model.session of
        Nothing ->
            case ( Debug.log "Guest" msg, model.pageModel ) of
                ( ChangedUrl url, _ ) ->
                    changeRouteTo (Route.fromUrl url) model

                ( GotLoginMsg subMsg, Login login ) ->
                    Login.update subMsg login
                        |> updateWith Login GotLoginMsg model

                ( GotSession session, _ ) ->
                    ( { model | session = session }
                    , Route.replaceUrl (Session.navKey session) Route.Home
                    )

                ( GotNavbar state, _ ) ->
                    ( { model | session = Session.changeNavState state model.session }
                    , Cmd.none
                    )

                ( _, _ ) ->
                    ( model
                    , Route.replaceUrl (Session.navKey model.session) Route.Login
                    )

        Just viewer ->
            case ( Debug.log "LoggedIn" msg, model.pageModel ) of
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
                                    , Nav.pushUrl (Session.navKey model.session) (Url.toString url)
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
                    Home.update subMsg home viewer
                        |> updateWith Home GotHomeMsg model

                ( GotEntryMsg subMsg, Entry entry ) ->
                    Entry.update subMsg entry viewer
                        |> updateWith Entry GotEntryMsg model

                ( GotSession session, _ ) ->
                    ( { model | session = session }
                    , Route.replaceUrl (Session.navKey session) Route.Home
                    )

                ( GotNavbar state, _ ) ->
                    ( { model | session = Session.changeNavState state model.session }
                    , Cmd.none
                    )

                ( _, _ ) ->
                    -- Disregard messages that arrived for the wrong page.
                    ( model, Cmd.none )


updateWith : (subModel -> PageModel) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( { model | pageModel = toModel subModel }
    , Cmd.map toMsg subCmd
    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ case model.pageModel of
            NotFound ->
                Sub.none

            Redirect ->
                Sub.none

            Home home ->
                Sub.map GotHomeMsg (Home.subscriptions home)

            Login login ->
                Sub.map GotLoginMsg (Login.subscriptions login)

            Entry entry ->
                Sub.map GotEntryMsg (Entry.subscriptions entry)
        , Session.changes GotSession (Session.navState model.session) (Session.navKey model.session)
        , Navbar.subscriptions (Session.navState model.session) GotNavbar
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
