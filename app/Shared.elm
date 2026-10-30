module Shared exposing (Data, Model, Msg(..), SharedMsg(..), meetupGroupUrl, template)

import BackendTask exposing (BackendTask)
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html exposing (Html)
import Html.Attributes as Attr
import Pages.Flags
import Pages.PageUrl exposing (PageUrl)
import Route exposing (Route)
import SharedTemplate exposing (SharedTemplate)
import Style
import UrlPath exposing (UrlPath)
import View exposing (View)


template : SharedTemplate Msg Model Data msg
template =
    { init = init
    , update = update
    , view = view
    , data = data
    , subscriptions = subscriptions
    , onPageChange = Nothing
    }


type Msg
    = SharedMsg SharedMsg


type alias Data =
    ()


type SharedMsg
    = NoOp


type alias Model =
    {}


init :
    Pages.Flags.Flags
    ->
        Maybe
            { path :
                { path : UrlPath
                , query : Maybe String
                , fragment : Maybe String
                }
            , metadata : route
            , pageUrl : Maybe PageUrl
            }
    -> ( Model, Effect Msg )
init _ _ =
    ( {}, Effect.none )


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        SharedMsg _ ->
            ( model, Effect.none )


subscriptions : UrlPath -> Model -> Sub Msg
subscriptions _ _ =
    Sub.none


data : BackendTask FatalError Data
data =
    BackendTask.succeed ()


siteName : String
siteName =
    "AI Safety Sweden"


view :
    Data
    ->
        { path : UrlPath
        , route : Maybe Route
        }
    -> Model
    -> (Msg -> msg)
    -> View msg
    -> { body : List (Html msg), title : String }
view _ _ _ _ pageView =
    { body =
        [ Html.div [ Attr.id "top" ]
            [ header
            , Html.main_ [] pageView.body
            , footer
            ]
        ]
    , title = pageView.title
    }


header : Html msg
header =
    Html.header []
        [ Html.nav
            (Style.container
                ++ [ Attr.attribute "aria-label" "Main"
                   , Attr.style "display" "flex"
                   , Attr.style "flex-wrap" "wrap"
                   , Attr.style "align-items" "center"
                   , Attr.style "justify-content" "space-between"
                   , Attr.style "gap" "12px"
                   , Attr.style "padding-block" "20px"
                   ]
            )
            [ Html.a
                [ Attr.href "#top"
                , Attr.style "display" "flex"
                , Attr.style "align-items" "center"
                , Attr.style "gap" "10px"
                , Attr.style "padding" "10px 0"
                , Attr.style "text-decoration" "none"
                , Attr.style "color" Style.textStrong
                , Attr.style "font-family" Style.fontDisplay
                , Attr.style "font-size" "18px"
                , Attr.style "font-weight" "700"
                , Attr.style "letter-spacing" "-0.01em"
                ]
                [ Html.span
                    [ Attr.attribute "aria-hidden" "true"
                    , Attr.style "display" "block"
                    , Attr.style "width" "12px"
                    , Attr.style "height" "12px"
                    , Attr.style "border-radius" "999px"
                    , Attr.style "background" Style.accent
                    ]
                    []
                , Html.span [] [ Html.text siteName ]
                ]
            , Html.div
                [ Attr.style "display" "flex"
                , Attr.style "flex-wrap" "wrap"
                , Attr.style "gap" "4px 8px"
                , Attr.style "font-size" "15px"
                , Attr.style "font-weight" "500"
                ]
                (List.map
                    (\( href, label ) ->
                        Html.a
                            [ Attr.href href
                            , Attr.style "padding" "12px"
                            , Attr.style "text-decoration" "none"
                            ]
                            [ Html.text label ]
                    )
                    navLinks
                )
            ]
        ]


footer : Html msg
footer =
    Html.footer [ Attr.style "border-top" ("1px solid " ++ Style.border) ]
        [ Html.div
            (Style.container
                ++ [ Attr.style "padding-block" "28px 36px"
                   , Attr.style "display" "flex"
                   , Attr.style "flex-wrap" "wrap"
                   , Attr.style "justify-content" "space-between"
                   , Attr.style "align-items" "center"
                   , Attr.style "gap" "12px"
                   , Attr.style "font-size" "15px"
                   , Attr.style "color" Style.textFaint
                   ]
            )
            [ Html.span [] [ Html.text (siteName ++ " · Stockholm, Sweden") ]
            , Html.div
                [ Attr.style "display" "flex"
                , Attr.style "flex-wrap" "wrap"
                , Attr.style "gap" "4px"
                ]
                (List.map
                    (\( href, label ) ->
                        Html.a [ Attr.href href, Attr.style "padding" "12px 10px" ] [ Html.text label ]
                    )
                    externalLinks
                )
            ]
        ]


navLinks : List ( String, String )
navLinks =
    [ ( substackUrl, "Blog" )
    , ( "#events", "Events" )
    , ( "#contact", "Contact" )
    , ( "#about", "About Us" )
    ]


externalLinks : List ( String, String )
externalLinks =
    [ ( substackUrl, "Substack" )
    , ( meetupGroupUrl, "Meetup" )
    , ( lumaUrl, "Luma" )
    , ( discordUrl, "Discord" )
    ]


substackUrl : String
substackUrl =
    "https://substack.com/@aisafetysweden"


meetupGroupUrl : String
meetupGroupUrl =
    "https://www.meetup.com/stockholm-ai-safety/"


{-| Placeholder until the group has a Luma page.
-}
lumaUrl : String
lumaUrl =
    "#"


{-| Placeholder until the group has a Discord invite link.
-}
discordUrl : String
discordUrl =
    "#"
