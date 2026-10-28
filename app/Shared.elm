module Shared exposing (Data, Model, Msg(..), SharedMsg(..), template)

import BackendTask exposing (BackendTask)
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html exposing (Html)
import Html.Attributes as Attr
import Pages.Flags
import Pages.PageUrl exposing (PageUrl)
import Route exposing (Route)
import SharedTemplate exposing (SharedTemplate)
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
    "Sweden AI Safety"


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
        [ Html.nav [ Attr.class "container nav", Attr.attribute "aria-label" "Main" ]
            [ Html.a [ Attr.class "brand", Attr.href "#top" ]
                [ Html.span [ Attr.class "brand-dot", Attr.attribute "aria-hidden" "true" ] []
                , Html.span [] [ Html.text siteName ]
                ]
            , Html.div [ Attr.class "nav-links" ] navLinks
            ]
        ]


footer : Html msg
footer =
    Html.footer [ Attr.class "footer" ]
        [ Html.div [ Attr.class "container footer-inner" ]
            [ Html.span [] [ Html.text (siteName ++ " · Stockholm, Sweden") ]
            , Html.div [ Attr.class "footer-links" ] navLinks
            ]
        ]


navLinks : List (Html msg)
navLinks =
    [ ( "#blog", "Blog" )
    , ( "#events", "Events" )
    , ( "#contact", "Contact" )
    , ( "#about", "About Us" )
    ]
        |> List.map (\( href, label ) -> Html.a [ Attr.href href ] [ Html.text label ])
