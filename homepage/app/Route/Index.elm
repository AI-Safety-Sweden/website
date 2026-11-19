module Route.Index exposing (ActionData, Data, Event, Model, Msg, RouteParams, route)

import BackendTask exposing (BackendTask)
import BackendTask.Custom
import Browser.Dom
import Date
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attr
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Pages.Url
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Shared
import Style
import Svg
import Svg.Attributes as SvgAttr
import Task
import Url
import UrlPath exposing (UrlPath)
import View exposing (View)


type alias Model =
    { nextEvent : Maybe Event
    }


type Msg
    = GotNextEvent (Result Http.Error (Maybe Event))
    | ScrolledToFragment


type alias RouteParams =
    {}


type alias Data =
    { nextEvent : Maybe Event
    }


type alias Event =
    { title : String
    , start : String
    , end : String
    , url : String
    , location : Maybe String
    }


type alias ActionData =
    {}


route : StatefulRoute RouteParams Data ActionData Model Msg
route =
    RouteBuilder.single
        { head = head
        , data = data
        }
        |> RouteBuilder.buildWithLocalState
            { view = view
            , init = init
            , update = update
            , subscriptions = subscriptions
            }


{-| The next event as of the build, so the page shows something before the browser fetches the current one.
It comes from netlify/luma.mjs, the same code the Netlify function in netlify/functions/next-event.mjs runs.
-}
data : BackendTask FatalError Data
data =
    BackendTask.Custom.run "nextEvent" Encode.null decodeNextEvent
        |> BackendTask.allowFatal
        |> BackendTask.map (\nextEvent -> { nextEvent = nextEvent })


{-| Luma's iCal feed doesn't allow browser requests, so this goes through the Netlify function in netlify/functions/next-event.mjs.
-}
fetchNextEvent : Cmd Msg
fetchNextEvent =
    Http.get
        { url = "/api/next-event"
        , expect = Http.expectJson GotNextEvent decodeNextEvent
        }


init : App Data ActionData RouteParams -> Shared.Model -> ( Model, Effect Msg )
init app _ =
    ( { nextEvent = app.data.nextEvent }
    , case app.url of
        Just pageUrl ->
            case pageUrl.fragment of
                Just fragment ->
                    Effect.batch [ Effect.fromCmd fetchNextEvent, Effect.fromCmd (scrollToFragment fragment) ]

                Nothing ->
                    Effect.fromCmd fetchNextEvent

        Nothing ->
            Effect.fromCmd fetchNextEvent
    )


{-| Links like "/#team" from other pages are followed without a page load, so the browser doesn't scroll to the section by itself.
-}
scrollToFragment : String -> Cmd Msg
scrollToFragment fragment =
    Browser.Dom.getElement fragment
        |> Task.andThen (\element -> Browser.Dom.setViewport 0 element.element.y)
        |> Task.attempt (\_ -> ScrolledToFragment)


update : App Data ActionData RouteParams -> Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update _ _ msg model =
    case msg of
        GotNextEvent (Ok nextEvent) ->
            ( { model | nextEvent = nextEvent }, Effect.none )

        GotNextEvent (Err _) ->
            ( model, Effect.none )

        ScrolledToFragment ->
            ( model, Effect.none )


subscriptions : RouteParams -> UrlPath -> Shared.Model -> Model -> Sub Msg
subscriptions _ _ _ _ =
    Sub.none


decodeNextEvent : Decode.Decoder (Maybe Event)
decodeNextEvent =
    Decode.nullable
        (Decode.map5 Event
            (Decode.field "title" Decode.string)
            (Decode.field "start" Decode.string)
            (Decode.field "end" Decode.string)
            (Decode.field "url" Decode.string)
            (Decode.field "location" (Decode.nullable Decode.string))
        )


description : String
description =
    "A Stockholm group for discussing the societal effects of AI. Events every other Wednesday evening."


head :
    App Data ActionData RouteParams
    -> List Head.Tag
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
        , description = description
        , locale = Nothing
        , title = "AI Safety Sweden"
        }
        |> Seo.website


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Model
    -> View (PagesMsg Msg)
view _ _ model =
    { title = "AI Safety Sweden"
    , body =
        [ hero model.nextEvent
        , section "mission" "Mission" [ mission ]
        , section "team" "Our team" [ team ]
        , section "what-we-do" "What we do" [ whatWeDo ]
        , groups
        , contact
        ]
    }


hero : Maybe Event -> Html msg
hero nextEvent =
    Html.section
        (Style.container
            ++ [ Attr.style "padding-block" "clamp(40px, 9vw, 80px)"
               , Attr.style "display" "flex"
               , Attr.style "flex-wrap" "wrap"
               , Attr.style "gap" "48px 64px"
               , Attr.style "align-items" "flex-end"
               , Attr.style "justify-content" "space-between"
               ]
        )
        [ Html.div
            [ Attr.style "flex" "1 1 520px"
            , Attr.style "min-width" "0"
            ]
            [ Html.h1
                [ Attr.style "margin" "0"
                , Attr.style "font-family" Style.fontDisplay
                , Attr.style "font-weight" "700"
                , Attr.style "font-size" "clamp(64px, 11vw, 168px)"
                , Attr.style "line-height" "0.95"
                , Attr.style "letter-spacing" "-0.04em"
                , Attr.style "color" Style.textStrong
                ]
                [ Html.text "AI Safety"
                , Html.br [] []
                , Html.span
                    [ Attr.style "color" Style.accent
                    , Attr.style "padding-left" "1.5px"
                    ]
                    [ Html.text "Sweden" ]
                ]
            , Html.p
                [ Attr.style "margin" "clamp(28px, 5vw, 40px) 0 0"
                , Attr.style "max-width" "560px"
                , Attr.style "font-size" "clamp(20px, 3.5vw, 24px)"
                , Attr.style "line-height" "1.45"
                ]
                [ Html.text "A space to discuss AI, spread awareness of its risks, and work on capacity building." ]
            , Html.a
                [ Attr.href Shared.joinUrl
                , Attr.style "display" "inline-block"
                , Attr.style "margin-top" "28px"
                , Attr.style "padding" "24px 16px 24px 32px"
                , Attr.style "border-radius" "16px"
                , Attr.style "background" Style.accent
                , Attr.style "color" Style.background
                , Attr.style "font-size" "20px"
                , Attr.style "font-weight" "600"
                , Attr.style "text-decoration" "none"
                , Attr.style "white-space" "pre"
                , Attr.style "line-height" "1.5"
                ]
                [ Html.div
                    [ Attr.style "display" "flex", Attr.style "align-items" "center", Attr.style "gap" "16px" ]
                    [ Html.text "Take part in the future\nBecome a member"
                    , Html.div
                        [ Attr.style "display" "inline-block"
                        , Attr.style "font-size" "32px"
                        , Attr.style "display" "flex"
                        ]
                        [ arrowRight ]
                    ]
                ]
            ]
        , eventCard nextEvent
        ]


arrowRight : Html msg
arrowRight =
    Svg.svg
        [ SvgAttr.viewBox "0 0 20 20"
        , SvgAttr.fill "currentColor"
        , SvgAttr.width "48px"
        ]
        [ Svg.path [ SvgAttr.fillRule "evenodd", SvgAttr.d "M3 10a.75.75 0 0 1 .75-.75h10.638L10.23 5.29a.75.75 0 1 1 1.04-1.08l5.5 5.25a.75.75 0 0 1 0 1.08l-5.5 5.25a.75.75 0 1 1-1.04-1.08l4.158-3.96H3.75A.75.75 0 0 1 3 10Z", SvgAttr.clipRule "evenodd" ] [] ]


eventCard : Maybe Event -> Html msg
eventCard nextEvent =
    Html.aside
        [ Attr.attribute "aria-label" "Next event"
        , Attr.style "flex" "1 1 340px"
        , Attr.style "min-width" "0"
        , Attr.style "max-width" "420px"
        , Attr.style "padding" "28px"
        , Attr.style "border" ("1px solid " ++ Style.borderStrong)
        , Attr.style "border-radius" "20px"
        , Attr.style "background" Style.surface
        ]
        (Html.div
            [ Attr.style "display" "flex"
            , Attr.style "align-items" "center"
            , Attr.style "justify-content" "space-between"
            , Attr.style "gap" "16px"
            ]
            [ Html.p
                [ Attr.style "margin" "0"
                , Attr.style "font-family" Style.fontSans
                , Attr.style "font-size" "15px"
                , Attr.style "font-weight" "600"
                , Attr.style "letter-spacing" "0.1em"
                , Attr.style "text-transform" "uppercase"
                , Attr.style "color" Style.accent
                ]
                [ Html.text "Next event" ]
            , Html.a
                [ Attr.href Shared.lumaCalendarUrl
                , Attr.style "font-family" Style.fontDisplay
                , Attr.style "font-size" "15px"
                , Attr.style "font-weight" "600"
                , Attr.style "text-decoration" "none"
                ]
                [ Html.text "Luma" ]
            ]
            :: eventCardContent nextEvent
        )


eventCardContent : Maybe Event -> List (Html msg)
eventCardContent nextEvent =
    case nextEvent of
        Just event ->
            let
                ( format, title ) =
                    splitFormat event.title
            in
            [ eventTitle title
            , Html.dl
                [ Attr.style "margin" "20px 0 0"
                , Attr.style "display" "grid"
                , Attr.style "grid-template-columns" "auto minmax(0, 1fr)"
                , Attr.style "gap" "10px 16px"
                , Attr.style "font-size" "16px"
                ]
                (List.concat
                    [ [ detailTerm "When", detailValue (formatWhen event.start event.end) ]
                    , case event.location of
                        Just location ->
                            [ detailTerm "Where", detailValue location ]

                        Nothing ->
                            []
                    , case format of
                        Just format2 ->
                            [ detailTerm "Format", detailValue format2 ]

                        Nothing ->
                            []
                    ]
                )
            , eventLink event.url "View event on Luma"
            ]

        Nothing ->
            [ eventTitle "No upcoming events yet"
            , eventLink Shared.lumaCalendarUrl "See past events on Luma"
            ]


eventTitle : String -> Html msg
eventTitle title =
    Html.p
        [ Attr.style "margin" "14px 0 0"
        , Attr.style "font-family" Style.fontDisplay
        , Attr.style "font-size" "26px"
        , Attr.style "font-weight" "600"
        , Attr.style "line-height" "1.2"
        , Attr.style "color" Style.textStrong
        ]
        [ Html.text title ]


eventLink : String -> String -> Html msg
eventLink url label =
    Html.a
        [ Attr.href url
        , Attr.style "margin-top" "20px"
        , Attr.style "display" "inline-flex"
        , Attr.style "align-items" "center"
        , Attr.style "gap" "8px"
        , Attr.style "min-height" "44px"
        , Attr.style "color" Style.textStrong
        , Attr.style "font-weight" "600"
        ]
        [ Html.text label
        , arrowIcon
        ]


{-| Event titles can start with the format in brackets, e.g. "[Reading Group] The Bottleneck in AI Safety".
-}
splitFormat : String -> ( Maybe String, String )
splitFormat title =
    case ( String.startsWith "[" title, String.indexes "]" title ) of
        ( True, closing :: _ ) ->
            ( Just (String.slice 1 closing title), String.trim (String.dropLeft (closing + 1) title) )

        _ ->
            ( Nothing, title )


{-| Times come like "2026-10-28T18:00", already in Stockholm local time.
-}
formatWhen : String -> String -> String
formatWhen start end =
    let
        day =
            case Date.fromIsoString (String.left 10 start) of
                Ok date ->
                    Date.format "EEEE d MMMM" date

                Err _ ->
                    String.left 10 start
    in
    day ++ ", " ++ String.slice 11 16 start ++ "–" ++ String.slice 11 16 end


detailTerm : String -> Html msg
detailTerm label =
    Html.dt [ Attr.style "color" Style.textFaint ] [ Html.text label ]


detailValue : String -> Html msg
detailValue value =
    Html.dd [ Attr.style "margin" "0" ] [ Html.text value ]


arrowIcon : Html msg
arrowIcon =
    Svg.svg
        [ SvgAttr.width "18"
        , SvgAttr.height "18"
        , SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        , Attr.attribute "aria-hidden" "true"
        ]
        [ Svg.path [ SvgAttr.d "M5 12h14" ] []
        , Svg.path [ SvgAttr.d "M13 6l6 6-6 6" ] []
        ]


section : String -> String -> List (Html msg) -> Html msg
section id label content =
    Html.section
        [ Attr.id id
        , Attr.style "border-top" ("1px solid " ++ Style.border)
        ]
        [ Html.div
            (Style.container
                ++ [ Attr.style "padding-block" "clamp(56px, 10vw, 72px)"
                   , Attr.style "display" "flex"
                   , Attr.style "flex-wrap" "wrap"
                   , Attr.style "gap" "32px 80px"
                   ]
            )
            [ Html.h2
                [ Attr.style "flex" "1 1 220px"
                , Attr.style "margin" "0"
                , Attr.style "font-family" Style.fontSans
                , Attr.style "font-size" "18px"
                , Attr.style "font-weight" "600"
                , Attr.style "letter-spacing" "0.08em"
                , Attr.style "text-transform" "uppercase"
                , Attr.style "color" Style.accent
                ]
                [ Html.text label ]
            , Html.div
                [ Attr.style "flex" "999 1 560px"
                , Attr.style "min-width" "0"
                , Attr.style "max-width" "860px"
                ]
                content
            ]
        ]


mission : Html msg
mission =
    Html.div []
        [ Html.p
            [ Attr.style "margin" "0"
            , Attr.style "font-family" Style.fontDisplay
            , Attr.style "font-size" "clamp(24px, 4.5vw, 30px)"
            , Attr.style "line-height" "1.35"
            , Attr.style "letter-spacing" "-0.01em"
            , Attr.style "font-weight" "500"
            , Attr.style "color" Style.textStrong
            ]
            [ Html.text missionTitle ]
        , Html.p
            [ Attr.style "margin" "40px 0 0"
            , Attr.style "max-width" "680px"
            , Attr.style "font-size" "18px"
            , Attr.style "line-height" "1.7"
            , Attr.style "color" Style.textMuted
            ]
            [ Html.text missionBody ]
        ]


missionTitle : String
missionTitle =
    "AI is advancing quickly, and our preparations have not kept pace."


missionBody : String
missionBody =
    "AI Safety Sweden aims to reduce catastrophic risks from AI through capacity building. We will do this by running events, fellowships, workshops, and more."


type alias TeamMember =
    { name : String
    , role : String
    , profile : Maybe ProfileLink
    , photo : Maybe String
    }


type ProfileLink
    = LinkedIn String
    | GitHub String


teamMembers : List TeamMember
teamMembers =
    [ { name = "Simon Holm"
      , role = "AI safety fieldbuilder"
      , profile = Just (LinkedIn "https://www.linkedin.com/in/simonholm97/")
      , photo = Just "/team/simon.jpg"
      }
    , { name = "Riccardo Conte"
      , role = "PhD student in AI runtime security assurance"
      , profile = Just (LinkedIn "https://www.linkedin.com/in/riccardoconte-aisafety/")
      , photo = Just "/team/riccardo.jpg"
      }
    , { name = "Vera Karlin"
      , role = "Bioinformatician"
      , profile = Just (LinkedIn "https://www.linkedin.com/in/vera-karlin/")
      , photo = Just "/team/vera.jpg"
      }
    , { name = "Martin Stewart"
      , role = "Web developer"
      , profile = Just (GitHub "https://github.com/MartinSStewart")
      , photo = Just "/team/martin.jpg"
      }
    , { name = "AJ Weeks"
      , role = "Lead organizer of AI Safety Stockholm"
      , profile = Just (LinkedIn "https://www.linkedin.com/in/aj-weeks/")
      , photo = Just "/team/ajweeks.jpg"
      }
    , { name = "Vivianne Manlai"
      , role = "AI governance researcher"
      , profile = Just (LinkedIn "https://www.linkedin.com/in/vivianne-manlai-a2130721b/")
      , photo = Just "/team/vivianne.jpg"
      }
    ]


team : Html msg
team =
    Html.ul
        [ Attr.style "list-style" "none"
        , Attr.style "margin" "0"
        , Attr.style "padding" "0"
        , Attr.style "display" "grid"
        , Attr.style "grid-template-columns" "repeat(auto-fill, minmax(160px, 1fr))"
        , Attr.style "gap" "32px 24px"
        ]
        (List.map teamMember teamMembers)


teamMember : TeamMember -> Html msg
teamMember member =
    Html.li []
        (List.concat
            [ [ case member.photo of
                    Just photo ->
                        portrait member.name photo

                    Nothing ->
                        portraitPlaceholder member.name
              , Html.p
                    [ Attr.style "margin" "16px 0 0"
                    , Attr.style "font-family" Style.fontDisplay
                    , Attr.style "font-size" "20px"
                    , Attr.style "font-weight" "600"
                    , Attr.style "line-height" "1.25"
                    , Attr.style "color" Style.textStrong
                    ]
                    [ Html.text member.name ]
              , Html.p
                    [ Attr.style "margin" "4px 0 0"
                    , Attr.style "font-size" "16px"
                    , Attr.style "line-height" "1.45"
                    , Attr.style "color" Style.textMuted
                    ]
                    [ Html.text member.role ]
              ]
            , case member.profile of
                Just (LinkedIn url) ->
                    [ profileLink member.name "LinkedIn" url ]

                Just (GitHub url) ->
                    [ profileLink member.name "GitHub" url ]

                Nothing ->
                    []
            ]
        )


profileLink : String -> String -> String -> Html msg
profileLink name site url =
    Html.a
        [ Attr.href url
        , Attr.attribute "aria-label" (name ++ " on " ++ site)
        , Attr.style "display" "inline-block"
        , Attr.style "padding-block" "8px"
        , Attr.style "font-size" "16px"
        , Attr.style "font-weight" "600"
        , Attr.style "color" Style.accent
        ]
        [ Html.text site ]


{-| The photos in public/team/ are already grayscale.
-}
portrait : String -> String -> Html msg
portrait name photo =
    Html.img
        [ Attr.src photo
        , Attr.alt ("Portrait of " ++ name)
        , Attr.attribute "loading" "lazy"
        , Attr.style "display" "block"
        , Attr.style "width" "100%"
        , Attr.style "aspect-ratio" "1 / 1"
        , Attr.style "object-fit" "cover"
        , Attr.style "border-radius" "12px"
        , Attr.style "border" ("1px solid " ++ Style.borderStrong)
        , Attr.style "background" Style.chrome
        ]
        []


{-| Stands in for a portrait photo until we have one.
-}
portraitPlaceholder : String -> Html msg
portraitPlaceholder name =
    Html.div
        [ Attr.attribute "role" "img"
        , Attr.attribute "aria-label" ("Portrait of " ++ name)
        , Attr.style "aspect-ratio" "1 / 1"
        , Attr.style "border-radius" "12px"
        , Attr.style "border" ("1px solid " ++ Style.borderStrong)
        , Attr.style "background" Style.chrome
        , Attr.style "overflow" "hidden"
        ]
        [ Svg.svg
            [ SvgAttr.viewBox "0 0 100 100"
            , SvgAttr.width "100%"
            , SvgAttr.height "100%"
            , SvgAttr.fill Style.borderStrong
            , Attr.attribute "aria-hidden" "true"
            , Attr.style "display" "block"
            ]
            [ Svg.circle [ SvgAttr.cx "50", SvgAttr.cy "40", SvgAttr.r "17" ] []
            , Svg.path [ SvgAttr.d "M14 100 C14 76 30 64 50 64 C70 64 86 76 86 100 Z" ] []
            ]
        ]


whatWeDo : Html msg
whatWeDo =
    Html.dl
        [ Attr.style "margin" "0"
        , Attr.style "display" "grid"
        , Attr.style "grid-template-columns" "repeat(auto-fit, minmax(240px, 1fr))"
        , Attr.style "gap" "16px"
        ]
        [ activity
            "Fellowships"
            "An online, 6-week course covering everything you need to know to get up to date with AI risk."
            [ Html.a
                [ Attr.href Shared.fellowshipUrl
                , Attr.style "display" "inline-block"
                , Attr.style "margin-top" "12px"
                , Attr.style "padding-block" "8px"
                , Attr.style "font-size" "18px"
                , Attr.style "font-weight" "600"
                , Attr.style "color" Style.accent
                ]
                [ Html.text "Apply for the fellowship" ]
            ]
        , activity "Local events" "Group discussions and seminars." []
        ]


activity : String -> String -> List (Html msg) -> Html msg
activity name text extra =
    Html.div
        [ Attr.style "padding" "24px"
        , Attr.style "border" ("1px solid " ++ Style.borderStrong)
        , Attr.style "border-radius" "16px"
        , Attr.style "background" Style.surface
        ]
        [ Html.dt
            [ Attr.style "font-family" Style.fontDisplay
            , Attr.style "font-size" "22px"
            , Attr.style "font-weight" "600"
            , Attr.style "color" Style.textStrong
            ]
            [ Html.text name ]
        , Html.dd
            [ Attr.style "margin" "8px 0 0"
            , Attr.style "font-size" "18px"
            , Attr.style "line-height" "1.6"
            , Attr.style "color" Style.textMuted
            ]
            (Html.text text :: extra)
        ]


groups : Html msg
groups =
    Html.section
        [ Attr.id "groups"
        , Attr.style "border-top" ("1px solid " ++ Style.border)
        ]
        [ Html.div
            (Style.container
                ++ [ Attr.style "padding-block" "clamp(56px, 10vw, 72px)"
                   , Attr.style "display" "flex"
                   , Attr.style "flex-wrap" "wrap"
                   , Attr.style "align-items" "center"
                   , Attr.style "gap" "40px 80px"
                   ]
            )
            [ Html.div
                [ Attr.style "flex" "1 1 220px"
                , Attr.style "display" "flex"
                , Attr.style "justify-content" "center"
                ]
                [ groupsMap ]
            , Html.div
                [ Attr.style "flex" "999 1 480px"
                , Attr.style "min-width" "0"
                , Attr.style "max-width" "760px"
                ]
                [ Html.h2
                    [ Attr.style "margin" "0"
                    , Attr.style "font-family" Style.fontDisplay
                    , Attr.style "font-size" "clamp(32px, 6vw, 48px)"
                    , Attr.style "font-weight" "700"
                    , Attr.style "letter-spacing" "-0.02em"
                    , Attr.style "line-height" "1.1"
                    , Attr.style "color" Style.textStrong
                    ]
                    [ Html.text "Find your local group" ]
                , Html.ul
                    [ Attr.style "list-style" "none"
                    , Attr.style "margin" "28px 0 0"
                    , Attr.style "padding" "0"
                    , Attr.style "display" "grid"
                    , Attr.style "grid-template-columns" "repeat(auto-fill, minmax(170px, 1fr))"
                    , Attr.style "gap" "12px"
                    ]
                    (List.map
                        (\city ->
                            Html.li []
                                [ Html.a
                                    [ Attr.href (Shared.joinUrl ++ "?city=" ++ Url.percentEncode city)
                                    , Attr.style "display" "flex"
                                    , Attr.style "align-items" "center"
                                    , Attr.style "gap" "12px"
                                    , Attr.style "padding" "16px 20px"
                                    , Attr.style "border" ("1px solid " ++ Style.borderStrong)
                                    , Attr.style "border-radius" "10px"
                                    , Attr.style "background" Style.surface
                                    , Attr.style "color" Style.textStrong
                                    , Attr.style "font-size" "18px"
                                    , Attr.style "font-weight" "600"
                                    , Attr.style "text-decoration" "none"
                                    ]
                                    [ Html.span
                                        [ Attr.style "width" "10px"
                                        , Attr.style "height" "10px"
                                        , Attr.style "flex" "none"
                                        , Attr.style "border-radius" "50%"
                                        , Attr.style "background" Style.accent
                                        , Attr.attribute "aria-hidden" "true"
                                        ]
                                        []
                                    , Html.text city
                                    ]
                                ]
                        )
                        groupCities
                    )
                , Html.p
                    [ Attr.style "margin" "28px 0 0"
                    , Attr.style "font-size" "18px"
                    , Attr.style "line-height" "1.6"
                    , Attr.style "color" Style.textMuted
                    ]
                    [ Html.text "No group in your city yet? "
                    , Html.a
                        [ Attr.href Shared.joinUrl
                        , Attr.style "color" Style.accent
                        , Attr.style "font-weight" "600"
                        ]
                        [ Html.text "Sign up and we'll help you start one →" ]
                    ]
                ]
            ]
        ]


contact : Html msg
contact =
    Html.section
        [ Attr.id "contact"
        , Attr.style "border-top" ("1px solid " ++ Style.border)
        ]
        [ Html.div
            (Style.container
                ++ [ Attr.style "padding-block" "clamp(56px, 10vw, 72px)"
                   , Attr.style "display" "flex"
                   , Attr.style "flex-wrap" "wrap"
                   , Attr.style "gap" "32px 80px"
                   ]
            )
            [ Html.h2
                [ Attr.style "flex" "1 1 220px"
                , Attr.style "margin" "0"
                , Attr.style "font-family" Style.fontSans
                , Attr.style "font-size" "18px"
                , Attr.style "font-weight" "600"
                , Attr.style "letter-spacing" "0.08em"
                , Attr.style "text-transform" "uppercase"
                , Attr.style "color" Style.accent
                ]
                [ Html.text "Contact" ]
            , Html.div
                [ Attr.style "flex" "999 1 560px"
                , Attr.style "min-width" "0"
                , Attr.style "max-width" "860px"
                , Attr.style "padding" "clamp(24px, 5vw, 36px)"
                , Attr.style "border" ("1px solid " ++ Style.borderStrong)
                , Attr.style "border-radius" "20px"
                , Attr.style "background" Style.surface
                ]
                [ Html.p
                    [ Attr.style "margin" "0"
                    , Attr.style "font-family" Style.fontDisplay
                    , Attr.style "font-size" "clamp(24px, 4.5vw, 30px)"
                    , Attr.style "font-weight" "600"
                    , Attr.style "line-height" "1.3"
                    , Attr.style "letter-spacing" "-0.01em"
                    , Attr.style "color" Style.textStrong
                    ]
                    [ Html.text "Get in touch" ]
                , Html.p
                    [ Attr.style "margin" "12px 0 0"
                    , Attr.style "max-width" "620px"
                    , Attr.style "font-size" "18px"
                    , Attr.style "line-height" "1.6"
                    , Attr.style "color" Style.textMuted
                    ]
                    [ Html.text "Questions, ideas for collaboration, or want to help out? Send us an email and we'll get back to you." ]
                , Html.div
                    [ Attr.style "margin-top" "24px"
                    , Attr.style "display" "flex"
                    , Attr.style "flex-wrap" "wrap"
                    , Attr.style "align-items" "center"
                    , Attr.style "gap" "12px 24px"
                    ]
                    [ Html.a
                        [ Attr.href ("mailto:" ++ Shared.contactEmail)
                        , Attr.style "display" "inline-block"
                        , Attr.style "max-width" "100%"
                        , Attr.style "padding" "12px 22px"
                        , Attr.style "border-radius" "999px"
                        , Attr.style "background" Style.accent
                        , Attr.style "color" Style.background
                        , Attr.style "font-size" "18px"
                        , Attr.style "font-weight" "600"
                        , Attr.style "text-decoration" "none"
                        , Attr.style "overflow-wrap" "anywhere"
                        ]
                        [ Html.text Shared.contactEmail ]
                    , Html.a
                        [ Attr.href Shared.linkedInUrl
                        , Attr.style "padding-block" "12px"
                        , Attr.style "font-size" "18px"
                        , Attr.style "font-weight" "600"
                        , Attr.style "color" Style.accent
                        ]
                        [ Html.text "Follow us on LinkedIn" ]
                    ]
                ]
            ]
        ]


{-| The cities with a group, in the order they're listed next to the map. Each links to the signup
form with its city filled in.
-}
groupCities : List String
groupCities =
    [ "Stockholm", "Uppsala", "Örebro", "Linköping", "Lund/Malmö" ]


type LabelSide
    = LabelLeft
    | LabelRight


groupsMap : Html msg
groupsMap =
    let
        city : LabelSide -> String -> Float -> Float -> Svg.Svg msg
        city side name x y =
            Svg.g []
                [ Svg.circle
                    [ SvgAttr.cx (String.fromFloat x)
                    , SvgAttr.cy (String.fromFloat y)
                    , SvgAttr.r "7"
                    , SvgAttr.fill Style.accent
                    ]
                    []
                , Svg.text_
                    [ SvgAttr.x
                        (String.fromFloat
                            (case side of
                                LabelLeft ->
                                    x - 14

                                LabelRight ->
                                    x + 14
                            )
                        )
                    , SvgAttr.textAnchor
                        (case side of
                            LabelLeft ->
                                "end"

                            LabelRight ->
                                "start"
                        )
                    , SvgAttr.y (String.fromFloat (y + 6))
                    , SvgAttr.fill Style.textStrong
                    , SvgAttr.fontSize "18"
                    , SvgAttr.fontWeight "600"
                    , SvgAttr.stroke Style.surface
                    , SvgAttr.strokeWidth "4"
                    , Attr.attribute "paint-order" "stroke"
                    ]
                    [ Svg.text name ]
                ]
    in
    Svg.svg
        [ SvgAttr.viewBox "0 0 300 672.6"
        , SvgAttr.width "100%"
        , SvgAttr.style "display: block; max-width: 220px; height: auto; font-family: 'IBM Plex Sans', system-ui, sans-serif"
        , Attr.attribute "role" "img"
        , Attr.attribute "aria-label" "Map of Sweden with groups in Stockholm, Uppsala, Örebro, Linköping and Lund/Malmö"
        ]
        [ Svg.path
            [ SvgAttr.d swedenOutline
            , SvgAttr.fill Style.surface
            , SvgAttr.stroke Style.borderStrong
            , SvgAttr.strokeWidth "1.5"
            , SvgAttr.strokeLinejoin "round"
            ]
            []
        , city LabelRight "Stockholm" 159.7 476.9
        , city LabelRight "Uppsala" 149.7 450.8
        , city LabelLeft "Örebro" 93.7 479.8
        , city LabelLeft "Linköping" 103.2 522.1
        , city LabelRight "Lund/Malmö" 45.0 657.7
        ]


{-| Simplified outline of Sweden, from Natural Earth (public domain).
-}
swedenOutline : String
swedenOutline =
    "M182.8 550.3L180.9 551.5L179.9 554.9L176.9 556.7L176.3 567.6L179.0 571.8L176.1 573.6L174.2 579.4L170.5 581.7L169.1 583.3L167.0 587.0L165.9 592.4L163.8 594.7L161.4 595.2L162.8 590.8L164.7 587.2L162.9 584.8L160.5 578.0L161.6 574.7L161.0 569.3L161.2 564.0L167.4 554.1L170.5 550.5L174.7 548.9L176.6 550.4L177.4 547.1L178.9 546.4L182.8 550.3ZM124.1 626.2L122.9 628.7L121.9 628.5L121.1 625.2L121.4 612.5L126.5 597.4L128.7 596.2L134.9 575.7L135.6 574.4L137.7 575.6L136.2 577.6L136.3 581.2L132.3 592.1L131.3 599.1L129.9 600.9L124.1 626.2ZM5.6 491.3L7.5 497.5L9.1 498.3L11.5 496.7L13.0 492.2L15.0 478.8L12.3 464.0L15.9 458.8L18.1 450.7L19.4 449.3L23.6 448.2L26.4 445.5L30.9 438.7L31.6 428.9L33.2 421.8L32.5 417.1L26.9 400.1L26.5 394.7L30.5 392.8L35.5 392.5L36.0 391.9L37.5 386.3L38.8 383.9L39.9 377.5L33.4 368.2L30.9 366.7L23.2 359.4L26.4 337.5L26.7 331.7L22.3 316.6L22.9 310.3L22.2 300.5L24.7 296.5L19.7 282.2L24.6 272.4L23.7 267.3L26.7 263.5L35.0 250.3L37.9 247.4L42.4 244.9L47.4 243.8L49.7 243.8L64.8 246.7L67.3 242.7L69.1 238.9L69.2 234.6L68.6 228.4L67.6 224.6L57.7 218.8L68.4 200.9L76.9 183.5L78.5 166.6L80.5 159.3L78.3 142.8L89.8 141.0L97.5 136.8L100.1 134.2L98.6 125.1L101.7 122.0L109.3 111.4L117.4 101.2L121.2 97.3L122.0 92.5L120.2 87.7L114.8 79.1L116.4 75.2L122.5 72.9L125.5 69.2L130.0 56.0L138.9 49.5L142.5 45.8L156.1 52.6L160.9 44.3L162.2 41.0L161.4 27.9L161.8 25.0L165.1 23.6L166.8 23.3L175.8 26.4L182.3 26.7L201.2 33.1L203.5 33.4L209.7 27.5L203.4 24.3L207.6 21.1L209.7 17.8L211.6 13.9L212.2 9.2L212.0 6.7L206.8 0.8L218.5 0.0L224.9 2.8L225.4 6.4L231.5 10.2L237.0 15.4L238.0 17.0L250.3 25.3L254.8 27.5L258.6 28.1L268.4 31.7L270.0 32.8L275.7 38.3L277.6 44.2L280.7 44.5L281.6 46.6L284.3 50.1L288.1 53.1L288.0 54.2L285.0 57.1L284.9 65.8L285.9 69.9L284.1 74.6L283.9 77.4L284.1 78.0L288.6 78.4L290.3 79.2L291.3 83.9L288.5 86.9L287.8 88.5L288.2 93.6L289.0 96.7L295.1 106.0L296.2 109.3L295.0 111.0L294.0 114.5L293.4 120.9L291.1 124.3L289.5 125.5L288.9 130.5L289.5 136.7L290.7 139.8L294.3 141.9L296.3 146.2L300.0 158.7L293.9 159.8L289.3 157.6L287.0 158.7L278.5 159.7L275.8 162.1L271.5 159.7L267.5 155.5L264.6 158.6L262.7 159.2L261.1 156.4L259.6 155.9L256.9 161.5L256.2 169.0L252.3 168.3L252.5 169.6L253.8 171.2L252.3 172.3L248.4 172.1L248.1 173.3L249.2 175.2L247.5 177.5L243.0 178.5L240.3 178.3L239.3 180.6L239.8 182.0L241.4 183.6L241.3 185.4L240.3 185.8L237.6 182.5L236.7 182.7L239.8 188.1L240.6 190.4L240.5 192.2L237.1 197.7L231.7 204.3L230.4 207.7L233.7 211.9L236.3 220.7L239.2 224.6L238.0 228.7L233.2 232.8L227.7 238.7L221.8 253.9L219.8 255.9L214.6 258.5L212.7 261.1L208.9 264.1L202.2 266.5L199.1 270.1L197.8 273.8L196.2 274.0L192.7 271.6L192.6 275.7L189.3 273.1L187.7 275.5L186.6 279.5L181.9 284.9L176.9 283.9L176.4 284.9L177.7 285.5L177.9 286.4L173.5 287.8L172.0 287.8L170.3 293.5L166.0 295.0L165.2 296.7L169.6 297.1L168.7 301.7L163.7 304.0L162.0 306.9L159.8 306.9L160.2 304.6L156.9 304.7L155.9 302.1L155.3 302.8L157.4 310.3L155.9 313.3L156.4 314.2L158.2 314.9L158.9 316.2L156.9 317.3L154.2 321.0L151.5 321.1L149.9 323.5L148.1 323.5L146.7 322.0L144.5 320.7L143.7 323.0L143.6 324.7L144.9 329.2L147.3 332.7L149.6 334.2L148.0 335.3L146.7 337.5L143.6 352.2L144.1 356.4L145.7 361.2L142.7 360.9L139.5 359.2L140.0 362.6L138.0 366.6L138.7 372.3L138.2 376.0L139.1 377.2L139.6 379.4L138.7 381.2L139.7 397.2L141.4 404.0L140.7 409.6L143.3 412.5L147.8 412.4L148.6 413.1L150.2 417.7L152.1 417.5L155.1 415.4L157.0 414.9L158.3 418.8L161.8 423.9L163.8 426.2L167.3 427.4L170.9 431.5L170.4 436.4L171.9 438.1L176.2 440.0L179.6 446.7L180.9 452.4L180.4 455.9L174.6 460.8L171.4 465.2L167.3 469.0L165.8 469.7L164.4 471.6L163.1 472.4L161.8 471.9L157.3 475.4L157.6 476.9L161.1 477.5L162.9 476.8L164.3 475.1L165.8 474.6L167.1 475.0L169.8 473.0L171.0 473.7L172.3 477.0L169.6 478.7L167.6 478.8L166.6 484.3L164.7 487.7L160.3 490.0L157.4 493.0L154.1 495.3L152.6 494.8L150.5 497.2L145.6 500.0L143.0 503.9L137.3 507.3L134.5 510.0L126.6 510.2L119.2 509.6L116.8 511.0L119.2 511.3L120.9 512.7L123.0 512.1L130.1 513.4L133.3 518.0L130.9 519.7L127.0 520.9L129.7 531.7L128.0 534.3L128.0 546.3L125.7 546.4L124.7 551.4L125.5 553.9L125.9 563.4L127.0 566.7L126.5 570.2L122.9 578.3L123.0 582.1L124.1 588.0L120.0 605.6L116.9 611.5L111.8 629.5L110.1 632.2L107.9 634.3L103.3 631.3L100.6 631.5L96.4 633.0L90.0 632.0L83.9 632.5L82.3 633.9L83.2 638.8L80.9 639.5L78.7 638.0L75.1 641.6L71.8 646.0L70.7 648.7L70.5 653.7L73.7 663.6L69.8 670.1L67.7 670.3L61.4 668.6L50.2 672.6L40.1 669.3L41.4 665.9L42.1 652.8L41.4 650.0L38.9 646.2L33.3 633.7L30.6 626.2L31.4 626.1L36.0 628.9L38.1 627.5L34.8 618.8L37.5 618.1L39.4 618.3L40.9 615.1L40.0 610.2L37.9 608.5L36.2 607.9L32.9 600.0L29.4 595.9L23.2 580.2L20.9 569.4L18.8 570.4L16.9 558.0L13.5 556.1L12.8 543.5L9.3 542.2L7.0 536.4L6.6 525.5L4.2 523.5L2.3 524.1L2.8 518.8L1.4 499.6L0.0 493.6L1.1 489.2L3.4 488.8L5.6 491.3ZM184.7 546.0L184.3 549.1L183.1 548.8L182.0 546.6L184.3 543.1L187.6 543.3L188.7 544.1L184.7 546.0ZM167.6 491.6L166.2 491.9L167.2 488.7L169.2 487.9L167.6 491.6ZM171.8 469.9L171.2 471.6L170.6 469.6L171.2 467.2L172.4 466.2L174.1 466.8L174.1 467.3L171.8 469.9Z"
