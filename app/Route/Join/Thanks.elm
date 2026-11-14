module Route.Join.Thanks exposing (ActionData, Data, Model, Msg, RouteParams, route)

import BackendTask exposing (BackendTask)
import FatalError exposing (FatalError)
import Head
import Head.Seo as Seo
import Html
import Html.Attributes as Attr
import Pages.Url
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatelessRoute)
import Shared
import Style
import UrlPath
import View exposing (View)


type alias Model =
    {}


type alias Msg =
    ()


type alias RouteParams =
    {}


type alias Data =
    {}


type alias ActionData =
    {}


route : StatelessRoute RouteParams Data ActionData
route =
    RouteBuilder.single
        { head = head
        , data = data
        }
        |> RouteBuilder.buildNoState { view = view }


data : BackendTask FatalError Data
data =
    BackendTask.succeed {}


head : App Data ActionData RouteParams -> List Head.Tag
head _ =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "AI Safety Sweden"
        , image =
            { url = [ "favicon.ico" ] |> UrlPath.join |> Pages.Url.fromPath
            , alt = "AI Safety Sweden"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = "Thanks for signing up to AI Safety Sweden."
        , locale = Nothing
        , title = "Welcome | AI Safety Sweden"
        }
        |> Seo.website


view : App Data ActionData RouteParams -> Shared.Model -> View (PagesMsg Msg)
view _ _ =
    { title = "Welcome | AI Safety Sweden"
    , body =
        [ Html.section
            (Style.container
                ++ [ Attr.style "padding-block" "clamp(40px, 9vw, 96px)" ]
            )
            [ Html.div
                [ Attr.style "max-width" "720px"
                , Attr.style "margin" "0 auto"
                ]
                [ Html.h1
                    [ Attr.style "margin" "0"
                    , Attr.style "font-family" Style.fontDisplay
                    , Attr.style "font-weight" "700"
                    , Attr.style "font-size" "clamp(40px, 8vw, 64px)"
                    , Attr.style "line-height" "1"
                    , Attr.style "letter-spacing" "-0.03em"
                    , Attr.style "color" Style.textStrong
                    ]
                    [ Html.text "Welcome!" ]
                , Html.p
                    [ Attr.style "margin" "28px 0 0"
                    , Attr.style "font-size" "clamp(20px, 3.5vw, 24px)"
                    , Attr.style "line-height" "1.45"
                    ]
                    [ Html.text "Thanks for signing up. Come and say hello on our Discord." ]
                , Html.a
                    [ Attr.href Shared.discordUrl
                    , Attr.style "display" "inline-block"
                    , Attr.style "margin-top" "28px"
                    , Attr.style "padding" "18px 32px"
                    , Attr.style "border-radius" "16px"
                    , Attr.style "background" Style.accent
                    , Attr.style "color" Style.background
                    , Attr.style "font-size" "20px"
                    , Attr.style "font-weight" "600"
                    , Attr.style "text-decoration" "none"
                    ]
                    [ Html.text "Join our Discord" ]
                ]
            ]
        ]
    }
