module Session exposing (Session, changeNavState, changes, cred, fromViewer, navKey, navState, viewer)

import Api exposing (Cred)
import Avatar exposing (Avatar)
import Bootstrap.Navbar as Navbar
import Browser.Navigation as Nav
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (custom, required)
import Json.Encode as Encode exposing (Value)
import Profile exposing (Profile)
import Time
import Viewer exposing (Viewer)



-- TYPES


type Session
    = LoggedIn Navbar.State Nav.Key Viewer
    | Guest Navbar.State Nav.Key



-- INFO


viewer : Session -> Maybe Viewer
viewer session =
    case session of
        LoggedIn _ _ val ->
            Just val

        Guest _ _ ->
            Nothing


cred : Session -> Maybe Cred
cred session =
    case session of
        LoggedIn _ _ val ->
            Just (Viewer.cred val)

        Guest _ _ ->
            Nothing


navKey : Session -> Nav.Key
navKey session =
    case session of
        LoggedIn _ key _ ->
            key

        Guest _ key ->
            key


navState : Session -> Navbar.State
navState session =
    case session of
        LoggedIn state _ _ ->
            state

        Guest state _ ->
            state



-- CHANGES


changes : (Session -> msg) -> Navbar.State -> Nav.Key -> Sub msg
changes toMsg state key =
    Api.viewerChanges (\maybeViewer -> toMsg (fromViewer state key maybeViewer)) Viewer.decoder


changeNavState : Navbar.State -> Session -> Session
changeNavState state session =
    case session of
        LoggedIn _ key v ->
            LoggedIn state key v

        Guest _ key ->
            Guest state key


fromViewer : Navbar.State -> Nav.Key -> Maybe Viewer -> Session
fromViewer state key maybeViewer =
    -- It's stored in localStorage as a JSON String;
    -- first decode the Value as a String, then
    -- decode that String as JSON.
    case maybeViewer of
        Just viewerVal ->
            LoggedIn state key viewerVal

        Nothing ->
            Guest state key
