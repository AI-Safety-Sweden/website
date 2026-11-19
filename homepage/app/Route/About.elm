module Route.About exposing (ActionData, Data, Model, Msg, RouteParams, missionBody, missionTitle, route)

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
        , description = "AI Safety Sweden aims to reduce catastrophic risks from AI through capacity building: events, fellowships, workshops, and more."
        , locale = Nothing
        , title = "About us | AI Safety Sweden"
        }
        |> Seo.website


view : App Data ActionData RouteParams -> Shared.Model -> View (PagesMsg Msg)
view _ _ =
    { title = "About us | AI Safety Sweden"
    , body =
        [ pageHeading
        , section "mission" "Mission" [ mission ]
        , section "team" "Our team" [ team ]
        , section "what-we-do" "What we do" [ whatWeDo ]
        ]
    }


pageHeading : Html msg
pageHeading =
    Html.div
        (Style.container
            ++ [ Attr.style "padding-block" "clamp(40px, 9vw, 72px) clamp(8px, 2vw, 16px)" ]
        )
        [ Html.h1
            [ Attr.style "margin" "0"
            , Attr.style "font-family" Style.fontDisplay
            , Attr.style "font-weight" "700"
            , Attr.style "font-size" "clamp(48px, 9vw, 96px)"
            , Attr.style "line-height" "1"
            , Attr.style "letter-spacing" "-0.04em"
            , Attr.style "color" Style.textStrong
            ]
            [ Html.text "About us" ]
        ]


section : String -> String -> List (Html msg) -> Html msg
section id label content =
    Html.section
        [ Attr.id id
        , Attr.style "border-top" ("1px solid " ++ Style.border)
        ]
        [ Html.div
            (Style.container
                ++ [ Attr.style "padding-block" "clamp(40px, 8vw, 64px)"
                   , Attr.style "display" "flex"
                   , Attr.style "flex-wrap" "wrap"
                   , Attr.style "gap" "24px 80px"
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
            [ Attr.style "margin" "24px 0 0"
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
    , linkedIn : Maybe String
    , photo : Maybe String
    }


teamMembers : List TeamMember
teamMembers =
    [ { name = "Simon Holm"
      , role = "AI safety fieldbuilder"
      , linkedIn = Just "https://www.linkedin.com/in/simonholm97/"
      , photo = Just "/team/simon.jpg"
      }
    , { name = "Riccardo Conte"
      , role = "PhD student in AI runtime security assurance"
      , linkedIn = Just "https://www.linkedin.com/in/riccardoconte-aisafety/"
      , photo = Just "/team/riccardo.jpg"
      }
    , { name = "Vera Karlin"
      , role = "Bioinformatician"
      , linkedIn = Just "https://www.linkedin.com/in/vera-karlin/"
      , photo = Nothing
      }
    , { name = "Martin Stewart"
      , role = "Web developer"
      , linkedIn = Nothing
      , photo = Just "/team/martin.jpg"
      }
    , { name = "AJ Weeks"
      , role = "Lead organizer of AI Safety Stockholm"
      , linkedIn = Just "https://www.linkedin.com/in/aj-weeks/"
      , photo = Just "/team/ajweeks.jpg"
      }
    , { name = "Vivianne Manlai"
      , role = "AI governance researcher"
      , linkedIn = Just "https://www.linkedin.com/in/vivianne-manlai-a2130721b/"
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
            , case member.linkedIn of
                Just url ->
                    [ Html.a
                        [ Attr.href url
                        , Attr.attribute "aria-label" (member.name ++ " on LinkedIn")
                        , Attr.style "display" "inline-block"
                        , Attr.style "padding-block" "8px"
                        , Attr.style "font-size" "16px"
                        , Attr.style "font-weight" "600"
                        , Attr.style "color" Style.accent
                        ]
                        [ Html.text "LinkedIn" ]
                    ]

                Nothing ->
                    []
            ]
        )


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
        ]
        []


whatWeDo : Html msg
whatWeDo =
    Html.dl
        [ Attr.style "margin" "0"
        , Attr.style "display" "grid"
        , Attr.style "grid-template-columns" "repeat(auto-fit, minmax(240px, 1fr))"
        , Attr.style "gap" "16px"
        ]
        [ activity "Fellowships" "An online, 6-week course covering everything you need to know to get up to date with AI risk."
        , activity "Local events" "Group discussions and seminars."
        ]


activity : String -> String -> Html msg
activity name text =
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
            [ Html.text text ]
        ]
