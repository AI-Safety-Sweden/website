module Route.Index exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import FatalError exposing (FatalError)
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attr
import Pages.Url
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatelessRoute)
import Shared
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
    { nextEvent : Event
    }


type alias Event =
    { title : String
    , when : String
    , venue : String
    , format : String
    , rsvpUrl : String
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


data : BackendTask FatalError Data
data =
    BackendTask.succeed
        { nextEvent =
            { title = "[EVENT TITLE]"
            , when = "Wednesday [DATE], [TIME]"
            , venue = "[VENUE]"
            , format = "[Discussion / Lecture / Social]"
            , rsvpUrl = "#events"
            }
        }


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


hero : Event -> Html msg
hero nextEvent =
    Html.section [ Attr.class "container hero" ]
        [ Html.h1 []
            [ Html.text "Sweden"
            , Html.br [] []
            , Html.span [] [ Html.text "AI " ]
            , Html.span [ Attr.class "accent" ] [ Html.text "Safety" ]
            ]
        , Html.div [ Attr.class "hero-row" ]
            [ Html.div [ Attr.class "hero-intro" ]
                [ Html.p [] [ Html.text "A space to discuss the development of beneficial AI, with talks, debates and socials in Stockholm." ]
                , Html.div [ Attr.class "actions" ]
                    [ Html.a [ Attr.class "btn btn-primary", Attr.href "#events" ] [ Html.text "Upcoming events" ]
                    , Html.a [ Attr.class "btn btn-secondary", Attr.href "#about" ] [ Html.text "About us" ]
                    ]
                ]
            , eventCard nextEvent
            ]
        ]


eventCard : Event -> Html msg
eventCard event =
    Html.aside [ Attr.class "event-card", Attr.attribute "aria-label" "Next event" ]
        [ Html.p [ Attr.class "eyebrow" ] [ Html.text "Next event" ]
        , Html.p [ Attr.class "event-title" ] [ Html.text event.title ]
        , Html.dl [ Attr.class "event-details" ]
            [ Html.dt [] [ Html.text "When" ]
            , Html.dd [] [ Html.text event.when ]
            , Html.dt [] [ Html.text "Where" ]
            , Html.dd [] [ Html.text (event.venue ++ ", Stockholm") ]
            , Html.dt [] [ Html.text "Format" ]
            , Html.dd [] [ Html.text event.format ]
            ]
        , Html.a [ Attr.class "rsvp", Attr.href event.rsvpUrl ]
            [ Html.text "RSVP"
            , arrowIcon
            ]
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
    Html.section [ Attr.id "about", Attr.class "about" ]
        [ Html.div [ Attr.class "container about-inner" ]
            [ Html.h2 [] [ Html.text "About the group" ]
            , Html.div [ Attr.class "about-body" ]
                [ Html.p [ Attr.class "about-lead" ]
                    [ Html.text "This group is for anyone interested in discussing the potential societal effects of artificial intelligence. Our mission is to raise awareness and provide a space for the discussion of the development of beneficial AI in a Swedish context. Whether you are a researcher, developer, policymaker, or are simply curious about the implications of AI, you are welcome to participate." ]
                , Html.div [ Attr.class "about-rest" ]
                    [ Html.p [] [ Html.text "We host events every other Wednesday evening. Our events span a range of formats and topics, including discussions, lectures, and debates, and cover everything from technical and philosophical topics to political and societal impacts. We also host more casual social events where you can get to know others in the area who want to better understand the huge potential impacts of this technology." ]
                    , Html.p [] [ Html.text "We're new to Meetup but have been around for a few years elsewhere. We hope to see you at an upcoming event!" ]
                    ]
                ]
            ]
        ]
