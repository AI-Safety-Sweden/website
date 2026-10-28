module Route.Index exposing (ActionData, Data, Event, Model, Msg, RouteParams, Venue, route)

import BackendTask exposing (BackendTask)
import BackendTask.Http
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
import UrlPath exposing (UrlPath)
import View exposing (View)


type alias Model =
    { nextEvent : Maybe Event
    }


type Msg
    = GotNextEvent (Result Http.Error (Maybe Event))


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
    , venue : Maybe Venue
    }


type alias Venue =
    { name : String
    , city : String
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
The query matches the one in netlify/functions/next-event.mjs.
-}
data : BackendTask FatalError Data
data =
    BackendTask.Http.post
        "https://api.meetup.com/gql-ext"
        (BackendTask.Http.jsonBody
            (Encode.object
                [ ( "query"
                  , Encode.string
                        """query { groupByUrlname(urlname: "stockholm-ai-safety") { events(first: 1, status: ACTIVE, sort: ASC) { edges { node { title dateTime endTime eventUrl venues { name city } } } } } }"""
                  )
                ]
            )
        )
        (BackendTask.Http.expectJson decodeNextEvent)
        |> BackendTask.allowFatal
        |> BackendTask.map (\nextEvent -> { nextEvent = nextEvent })


{-| Meetup's API doesn't allow browser requests, so this goes through the Netlify function in netlify/functions/next-event.mjs.
-}
fetchNextEvent : Cmd Msg
fetchNextEvent =
    Http.get
        { url = "/api/next-event"
        , expect = Http.expectJson GotNextEvent decodeNextEvent
        }


init : App Data ActionData RouteParams -> Shared.Model -> ( Model, Effect Msg )
init app _ =
    ( { nextEvent = app.data.nextEvent }, Effect.fromCmd fetchNextEvent )


update : App Data ActionData RouteParams -> Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update _ _ msg model =
    case msg of
        GotNextEvent (Ok nextEvent) ->
            ( { model | nextEvent = nextEvent }, Effect.none )

        GotNextEvent (Err _) ->
            ( model, Effect.none )


subscriptions : RouteParams -> UrlPath -> Shared.Model -> Model -> Sub Msg
subscriptions _ _ _ _ =
    Sub.none


meetupGroupUrl : String
meetupGroupUrl =
    "https://www.meetup.com/stockholm-ai-safety/"


decodeNextEvent : Decode.Decoder (Maybe Event)
decodeNextEvent =
    Decode.at [ "data", "groupByUrlname", "events", "edges" ]
        (Decode.list (Decode.field "node" decodeEvent))
        |> Decode.map List.head


decodeEvent : Decode.Decoder Event
decodeEvent =
    Decode.map5 Event
        (Decode.field "title" Decode.string)
        (Decode.field "dateTime" Decode.string)
        (Decode.field "endTime" Decode.string)
        (Decode.field "eventUrl" Decode.string)
        (Decode.field "venues"
            (Decode.list
                (Decode.map2 Venue
                    (Decode.field "name" Decode.string)
                    (Decode.field "city" Decode.string)
                )
            )
            |> Decode.map List.head
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
        , siteName = "Sweden AI Safety"
        , image =
            { url = [ "favicon.ico" ] |> UrlPath.join |> Pages.Url.fromPath
            , alt = "Sweden AI Safety"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = description
        , locale = Nothing
        , title = "Sweden AI Safety"
        }
        |> Seo.website


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Model
    -> View (PagesMsg Msg)
view _ _ model =
    { title = "Sweden AI Safety"
    , body =
        [ hero model.nextEvent
        , about
        ]
    }


hero : Maybe Event -> Html msg
hero nextEvent =
    Html.section
        (Style.container ++ [ Attr.style "padding-block" "clamp(48px, 12vw, 80px) clamp(64px, 14vw, 96px)" ])
        [ Html.h1
            [ Attr.style "margin" "0"
            , Attr.style "font-family" Style.fontDisplay
            , Attr.style "font-weight" "700"
            , Attr.style "font-size" "clamp(64px, 11vw, 168px)"
            , Attr.style "line-height" "0.9"
            , Attr.style "letter-spacing" "-0.045em"
            , Attr.style "color" Style.textStrong
            ]
            [ Html.text "Sweden"
            , Html.br [] []
            , Html.span [] [ Html.text "AI " ]
            , Html.span [ Attr.style "color" Style.accent ] [ Html.text "Safety" ]
            ]
        , Html.div
            [ Attr.style "margin-top" "clamp(40px, 9vw, 64px)"
            , Attr.style "display" "flex"
            , Attr.style "flex-wrap" "wrap"
            , Attr.style "gap" "40px"
            , Attr.style "align-items" "flex-end"
            , Attr.style "justify-content" "space-between"
            ]
            [ Html.div
                [ Attr.style "flex" "1 1 420px"
                , Attr.style "min-width" "0"
                , Attr.style "max-width" "560px"
                ]
                [ Html.p
                    [ Attr.style "margin" "0"
                    , Attr.style "font-size" "clamp(20px, 3.5vw, 24px)"
                    , Attr.style "line-height" "1.45"
                    ]
                    [ Html.text "A space to discuss the development of beneficial AI, with talks, debates and socials in Stockholm." ]
                , Html.div
                    [ Attr.style "margin-top" "32px"
                    , Attr.style "display" "flex"
                    , Attr.style "flex-wrap" "wrap"
                    , Attr.style "gap" "12px"
                    ]
                    [ Html.a
                        (buttonStyle
                            ++ [ Attr.href "#events"
                               , Attr.style "background" Style.accent
                               , Attr.style "color" Style.background
                               ]
                        )
                        [ Html.text "Upcoming events" ]
                    , Html.a
                        (buttonStyle
                            ++ [ Attr.href "#about"
                               , Attr.style "border" ("1px solid " ++ Style.borderButton)
                               , Attr.style "color" Style.text
                               ]
                        )
                        [ Html.text "About us" ]
                    ]
                ]
            , eventCard nextEvent
            ]
        ]


buttonStyle : List (Html.Attribute msg)
buttonStyle =
    [ Attr.style "display" "inline-flex"
    , Attr.style "align-items" "center"
    , Attr.style "min-height" "52px"
    , Attr.style "padding" "0 26px"
    , Attr.style "border-radius" "999px"
    , Attr.style "text-decoration" "none"
    , Attr.style "font-size" "16px"
    , Attr.style "font-weight" "600"
    ]


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
                , Attr.style "font-family" Style.fontDisplay
                , Attr.style "font-size" "13px"
                , Attr.style "font-weight" "600"
                , Attr.style "letter-spacing" "0.1em"
                , Attr.style "text-transform" "uppercase"
                , Attr.style "color" Style.accent
                ]
                [ Html.text "Next event" ]
            , Html.a
                [ Attr.href meetupGroupUrl
                , Attr.style "display" "inline-flex"
                , Attr.style "align-items" "center"
                , Attr.style "gap" "6px"
                , Attr.style "font-family" Style.fontDisplay
                , Attr.style "font-size" "15px"
                , Attr.style "font-weight" "600"
                , Attr.style "text-decoration" "none"
                ]
                [ meetupLogo
                , Html.text "Meetup"
                ]
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
                    , case event.venue of
                        Just venue ->
                            [ detailTerm "Where", detailValue (venue.name ++ ", " ++ venue.city) ]

                        Nothing ->
                            []
                    , case format of
                        Just format2 ->
                            [ detailTerm "Format", detailValue format2 ]

                        Nothing ->
                            []
                    ]
                )
            , eventLink event.url "View event on Meetup"
            ]

        Nothing ->
            [ eventTitle "No upcoming events yet"
            , eventLink meetupGroupUrl "See past events on Meetup"
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


{-| Meetup titles start with the format in brackets, e.g. "[Reading Group] The Bottleneck in AI Safety".
-}
splitFormat : String -> ( Maybe String, String )
splitFormat title =
    case ( String.startsWith "[" title, String.indexes "]" title ) of
        ( True, closing :: _ ) ->
            ( Just (String.slice 1 closing title), String.trim (String.dropLeft (closing + 1) title) )

        _ ->
            ( Nothing, title )


{-| Meetup gives times like "2026-10-28T18:00:00+01:00", already in Stockholm local time.
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


{-| Meetup's logo, from Simple Icons (CC0).
-}
meetupLogo : Html msg
meetupLogo =
    Svg.svg
        [ SvgAttr.width "20"
        , SvgAttr.height "20"
        , SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.fill "#ED1C40"
        , Attr.attribute "aria-hidden" "true"
        ]
        [ Svg.path [ SvgAttr.d "M6.98.555a.518.518 0 0 0-.105.011.53.53 0 1 0 .222 1.04.533.533 0 0 0 .409-.633.531.531 0 0 0-.526-.418zm6.455.638a.984.984 0 0 0-.514.143.99.99 0 1 0 1.02 1.699.99.99 0 0 0 .34-1.36.992.992 0 0 0-.846-.482zm-3.03 2.236a5.029 5.029 0 0 0-4.668 3.248 3.33 3.33 0 0 0-1.46.551 3.374 3.374 0 0 0-.94 4.562 3.634 3.634 0 0 0-.605 4.649 3.603 3.603 0 0 0 2.465 1.597c.018.732.238 1.466.686 2.114a3.9 3.9 0 0 0 5.423.992c.068-.047.12-.106.184-.157.987.881 2.47 1.026 3.607.24a2.91 2.91 0 0 0 1.162-1.69 4.238 4.238 0 0 0 2.584-.739 4.274 4.274 0 0 0 1.19-5.789 2.466 2.466 0 0 0 .433-3.308 2.448 2.448 0 0 0-1.316-.934 4.436 4.436 0 0 0-.776-2.873 4.467 4.467 0 0 0-5.195-1.656 5.106 5.106 0 0 0-2.773-.807zm-5.603.817a.759.759 0 0 0-.423.135.758.758 0 1 0 .863 1.248.757.757 0 0 0 .193-1.055.758.758 0 0 0-.633-.328zm15.994 2.37a.842.842 0 0 0-.47.151.845.845 0 1 0 1.175.215.845.845 0 0 0-.705-.365zm-8.15 1.028c.063 0 .124.005.182.014a.901.901 0 0 1 .45.187c.169.134.273.241.432.393.24.227.414.089.534.02.208-.122.369-.219.984-.208.633.011 1.363.237 1.514 1.317.168 1.199-1.966 4.289-1.817 5.722.106 1.01 1.815.299 1.96 1.22.186 1.198-2.136.753-2.667.493-.832-.408-1.337-1.34-1.12-2.26.16-.688 1.7-3.498 1.757-3.93.059-.44-.177-.476-.324-.484-.19-.01-.34.081-.526.362-.169.255-2.082 4.085-2.248 4.398-.296.56-.67.694-1.044.674-.548-.029-.798-.32-.72-.848.047-.31 1.26-3.049 1.323-3.476.039-.265-.013-.546-.275-.68-.263-.135-.572.07-.664.227-.128.215-1.848 4.706-2.032 5.038-.316.576-.65.76-1.152.784-1.186.056-2.065-.92-1.678-2.116.173-.532 1.316-4.571 1.895-5.599.389-.69 1.468-1.216 2.217-.892.387.167.925.437 1.084.507.366.163.759-.277.913-.412.155-.134.302-.276.49-.357.142-.06.343-.095.532-.094zm10.88 2.057a.468.468 0 0 0-.093.011.467.467 0 0 0-.36.555.47.47 0 0 0 .557.36.47.47 0 0 0 .36-.557.47.47 0 0 0-.464-.37zm-22.518.81a.997.997 0 0 0-.832.434 1 1 0 1 0 1.39-.258 1 1 0 0 0-.558-.176zm21.294 2.094a.635.635 0 0 0-.127.013.627.627 0 0 0-.48.746.628.628 0 0 0 .746.483.628.628 0 0 0 .482-.746.63.63 0 0 0-.621-.496zm-18.24 6.097a.453.453 0 0 0-.092.012.464.464 0 1 0 .195.908.464.464 0 0 0 .356-.553.465.465 0 0 0-.459-.367zm13.675 1.55a1.044 1.044 0 0 0-.583.187 1.047 1.047 0 1 0 1.456.265 1.044 1.044 0 0 0-.873-.451zM11.4 22.154a.643.643 0 0 0-.36.115.646.646 0 0 0-.164.899.646.646 0 0 0 .899.164.646.646 0 0 0 .164-.898.646.646 0 0 0-.54-.28z" ] []
        ]


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


about : Html msg
about =
    Html.section
        [ Attr.id "about"
        , Attr.style "border-top" ("1px solid " ++ Style.border)
        ]
        [ Html.div
            (Style.container
                ++ [ Attr.style "padding-block" "clamp(64px, 14vw, 96px)"
                   , Attr.style "display" "flex"
                   , Attr.style "flex-wrap" "wrap"
                   , Attr.style "gap" "32px 80px"
                   ]
            )
            [ Html.h2
                [ Attr.style "flex" "1 1 220px"
                , Attr.style "margin" "0"
                , Attr.style "font-family" Style.fontDisplay
                , Attr.style "font-size" "15px"
                , Attr.style "font-weight" "600"
                , Attr.style "letter-spacing" "0.08em"
                , Attr.style "text-transform" "uppercase"
                , Attr.style "color" Style.accent
                ]
                [ Html.text "About the group" ]
            , Html.div
                [ Attr.style "flex" "999 1 560px"
                , Attr.style "min-width" "0"
                , Attr.style "max-width" "860px"
                ]
                [ Html.p
                    [ Attr.style "margin" "0"
                    , Attr.style "font-family" Style.fontDisplay
                    , Attr.style "font-size" "clamp(24px, 4.5vw, 30px)"
                    , Attr.style "line-height" "1.35"
                    , Attr.style "letter-spacing" "-0.01em"
                    , Attr.style "font-weight" "500"
                    , Attr.style "color" Style.textStrong
                    ]
                    [ Html.text "This group is for anyone interested in discussing the potential societal effects of artificial intelligence. Our mission is to raise awareness and provide a space for the discussion of the development of beneficial AI in a Swedish context. Whether you are a researcher, developer, policymaker, or are simply curious about the implications of AI, you are welcome to participate." ]
                , Html.div
                    [ Attr.style "margin-top" "40px"
                    , Attr.style "max-width" "680px"
                    , Attr.style "display" "flex"
                    , Attr.style "flex-direction" "column"
                    , Attr.style "gap" "20px"
                    , Attr.style "font-size" "18px"
                    , Attr.style "line-height" "1.7"
                    , Attr.style "color" Style.textMuted
                    ]
                    [ Html.p [ Attr.style "margin" "0" ] [ Html.text "We host events every other Wednesday evening. Our events span a range of formats and topics, including discussions, lectures, and debates, and cover everything from technical and philosophical topics to political and societal impacts. We also host more casual social events where you can get to know others in the area who want to better understand the huge potential impacts of this technology." ]
                    , Html.p [ Attr.style "margin" "0" ] [ Html.text "We're new to Meetup but have been around for a few years elsewhere. We hope to see you at an upcoming event!" ]
                    ]
                ]
            ]
        ]
