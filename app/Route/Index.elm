module Route.Index exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import BackendTask.Http
import Date
import FatalError exposing (FatalError)
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Decode as Decode
import Json.Encode as Encode
import Pages.Url
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatelessRoute)
import Shared
import Style
import Svg
import Svg.Attributes as SvgAttr
import UrlPath
import View exposing (View)


type alias Model =
    {}


type alias Msg =
    ()


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


route : StatelessRoute RouteParams Data ActionData
route =
    RouteBuilder.single
        { head = head
        , data = data
        }
        |> RouteBuilder.buildNoState { view = view }


{-| Fetched at build time because Meetup's API and iCal feed don't allow requests from the browser.
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
        (BackendTask.Http.expectJson nextEventDecoder)
        |> BackendTask.allowFatal
        |> BackendTask.map (\nextEvent -> { nextEvent = nextEvent })


meetupGroupUrl : String
meetupGroupUrl =
    "https://www.meetup.com/stockholm-ai-safety/"


nextEventDecoder : Decode.Decoder (Maybe Event)
nextEventDecoder =
    Decode.at [ "data", "groupByUrlname", "events", "edges" ]
        (Decode.list (Decode.field "node" eventDecoder))
        |> Decode.map List.head


eventDecoder : Decode.Decoder Event
eventDecoder =
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
    -> View (PagesMsg Msg)
view app _ =
    { title = "Sweden AI Safety"
    , body =
        [ hero app.data.nextEvent
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
        (Html.p
            [ Attr.style "margin" "0"
            , Attr.style "font-family" Style.fontDisplay
            , Attr.style "font-size" "13px"
            , Attr.style "font-weight" "600"
            , Attr.style "letter-spacing" "0.1em"
            , Attr.style "text-transform" "uppercase"
            , Attr.style "color" Style.accent
            ]
            [ Html.text "Next event" ]
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
            , eventLink event.url "RSVP"
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
