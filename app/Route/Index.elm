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
        , about
        , groups
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
               , Attr.style "align-items" "center"
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
                , Attr.style "line-height" "0.9"
                , Attr.style "letter-spacing" "-0.045em"
                , Attr.style "color" Style.textStrong
                ]
                [ Html.text "AI Safety"
                , Html.br [] []
                , Html.span [ Attr.style "color" Style.accent ] [ Html.text "Sweden" ]
                ]
            , Html.p
                [ Attr.style "margin" "clamp(28px, 5vw, 40px) 0 0"
                , Attr.style "max-width" "560px"
                , Attr.style "font-size" "clamp(20px, 3.5vw, 24px)"
                , Attr.style "line-height" "1.45"
                ]
                [ Html.text "A space to discuss AI, spread awareness of its risks, and organize political activism." ]
            ]
        , eventCard nextEvent
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
                [ Attr.href Shared.meetupGroupUrl
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
            , eventLink Shared.meetupGroupUrl "See past events on Meetup"
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
                ++ [ Attr.style "padding-block" "clamp(56px, 10vw, 72px)"
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
                [ Html.text "About us" ]
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
                    [ Html.text "AI has the potential to greatly benefit humanity, but there are existential risks in developing it too quickly and recklessly. We want to help inform the public and politicians about these risks as well offer a social space where people can discuss and learn more about AI." ]
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
                    [ Html.p [ Attr.style "margin" "0" ] [ Html.text "Events are typically Wednesday and Thursday evening. They include discussions, lectures, workshops, and debates, and cover everything from technical and philosophical topics to political and societal impacts." ]
                    , Html.p [ Attr.style "margin" "0" ] [ Html.text "We hope to see you at an upcoming event!" ]
                    ]
                ]
            ]
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
                [ Html.text "Where we are" ]
            , Html.div
                [ Attr.style "flex" "999 1 560px"
                , Attr.style "min-width" "0"
                ]
                [ groupsMap ]
            ]
        ]


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
        , SvgAttr.style "display: block; max-width: 220px; height: auto; font-family: 'Space Grotesk', system-ui, sans-serif"
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
