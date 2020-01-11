module Page exposing (view, viewErrors, viewHeader)

import Api exposing (Cred)
import Avatar
import Bootstrap.Navbar as Navbar
import Browser exposing (Document)
import Html exposing (Html, a, button, div, footer, i, img, li, nav, p, span, text, ul)
import Html.Attributes exposing (class, classList, href, style)
import Html.Events exposing (onClick)
import Profile
import Route exposing (Route)
import Session exposing (Session)
import Username exposing (Username)
import Viewer exposing (Viewer)


{-| Take a page's Html and frames it with a header and footer.

The caller provides the current user, so we can display in either
"signed in" (rendering username) or "signed out" mode.

isLoading is for determining whether we should show a loading spinner
in the header. (This comes up during slow page transitions.)

-}
view : { title : String, content : Html msg } -> Document msg
view { title, content } =
    { title = title ++ " - Hefti"
    , body = [ content ]
    }


viewHeader : (Navbar.State -> msg) -> Navbar.State -> Maybe Viewer -> Html msg
viewHeader msg state maybeViewer =
    Navbar.config msg
        |> Navbar.withAnimation
        |> Navbar.dark
        |> Navbar.brand [ Route.href Route.Home ] [ text "Hefti" ]
        |> Navbar.items
            [ Navbar.itemLink [ Route.href Route.Entry ] [ text "Entry" ]
            , Navbar.itemLink [ Route.href Route.Login ] [ text "Login" ]
            , Navbar.itemLink [] [ text "test" ]
            ]
        |> Navbar.view state


{-| Render dismissable errors. We use this all over the place!
-}
viewErrors : msg -> List String -> Html msg
viewErrors dismissErrors errors =
    if List.isEmpty errors then
        Html.text ""

    else
        div
            [ class "error-messages"
            , style "position" "fixed"
            , style "top" "0"
            , style "background" "rgb(250, 250, 250)"
            , style "padding" "20px"
            , style "border" "1px solid"
            ]
        <|
            List.map (\error -> p [] [ text error ]) errors
                ++ [ button [ onClick dismissErrors ] [ text "Ok" ] ]
