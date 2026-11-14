module Route.Join exposing (ActionData, Data, Involvement, Model, Msg, RouteParams, route)

import BackendTask exposing (BackendTask)
import Dict exposing (Dict)
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events
import Pages.Url
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Set exposing (Set)
import Shared
import Style
import UrlPath exposing (UrlPath)
import View exposing (View)


type alias Model =
    { involvement : Maybe Involvement
    , checked : Dict String (Set String)
    }


type Involvement
    = Participant
    | Organizer
    | OccasionalContributor


type Msg
    = SelectedInvolvement Involvement
    | ToggledCheckbox String String Bool


type alias RouteParams =
    {}


type alias Data =
    {}


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


data : BackendTask FatalError Data
data =
    BackendTask.succeed {}


init : App Data ActionData RouteParams -> Shared.Model -> ( Model, Effect Msg )
init _ _ =
    ( { involvement = Nothing, checked = Dict.empty }, Effect.none )


update : App Data ActionData RouteParams -> Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update _ _ msg model =
    case msg of
        SelectedInvolvement involvement ->
            ( { model | involvement = Just involvement }, Effect.none )

        ToggledCheckbox name value isChecked ->
            let
                checked =
                    Maybe.withDefault Set.empty (Dict.get name model.checked)

                checked2 =
                    if isChecked then
                        Set.insert value checked

                    else
                        Set.remove value checked
            in
            ( { model | checked = Dict.insert name checked2 model.checked }, Effect.none )


subscriptions : RouteParams -> UrlPath -> Shared.Model -> Model -> Sub Msg
subscriptions _ _ _ _ =
    Sub.none


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
        , description = "Sign up to become a member of AI Safety Sweden and join our Discord."
        , locale = Nothing
        , title = "Become a member | AI Safety Sweden"
        }
        |> Seo.website


view : App Data ActionData RouteParams -> Shared.Model -> Model -> View (PagesMsg Msg)
view _ _ model =
    { title = "Become a member | AI Safety Sweden"
    , body = [ Html.map PagesMsg.fromMsg (page model) ]
    }


page : Model -> Html Msg
page model =
    Html.section
        (Style.container
            ++ [ Attr.style "padding-block" "clamp(40px, 8vw, 72px)" ]
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
                [ Html.text "Become a member" ]
            , Html.div
                [ Attr.style "margin-top" "28px"
                , Attr.style "display" "flex"
                , Attr.style "flex-direction" "column"
                , Attr.style "gap" "16px"
                , Attr.style "font-size" "18px"
                , Attr.style "line-height" "1.6"
                , Attr.style "color" Style.textMuted
                ]
                [ Html.p [ Attr.style "margin" "0" ]
                    [ Html.text "AI Safety Sweden is a community of researchers, professionals and students in Sweden who are interested in, or already working on, AI safety, interpretability, evaluation, alignment and AI governance. The community organizes seminars, events, mentorship programmes, and teaching and outreach activities." ]
                , Html.p [ Attr.style "margin" "0" ]
                    [ Html.text "This form helps us get to know who you are and what interests you, understand how you'd like to take part (as a member or by helping organize the community), and, if you want to contribute, learn which working groups you'd like to join." ]
                , Html.p [ Attr.style "margin" "0" ]
                    [ Html.text "It takes about 5–10 minutes if you just want to join as a member, or 10–15 minutes if you also want to help organize." ]
                ]
            , Html.form
                [ Attr.method "post"
                , Attr.action "/api/join"
                , Attr.style "margin-top" "48px"
                , Attr.style "display" "flex"
                , Attr.style "flex-direction" "column"
                , Attr.style "gap" "48px"
                ]
                (List.concat
                    [ [ formSection "About you" "" (List.map (questionView model.checked) aboutYou)
                      , formSection "Your interests"
                            ""
                            (List.map (questionView model.checked) interests ++ [ involvementView ])
                      ]
                    , case model.involvement of
                        Just OccasionalContributor ->
                            [ formSection "Occasional contributors"
                                occasionalIntro
                                (List.map (questionView model.checked) occasionalQuestions)
                            ]

                        Just Organizer ->
                            [ formSection "Organizers"
                                organizerIntro
                                (List.map (questionView model.checked) organizerQuestions)
                            ]

                        Just Participant ->
                            []

                        Nothing ->
                            []
                    , [ honeypot
                      , consentView
                      , submitButton
                      ]
                    ]
                )
            ]
        ]


formSection : String -> String -> List (Html msg) -> Html msg
formSection title intro questions =
    Html.div
        [ Attr.style "display" "flex"
        , Attr.style "flex-direction" "column"
        , Attr.style "gap" "32px"
        ]
        (Html.div []
            [ Html.h2
                [ Attr.style "margin" "0"
                , Attr.style "padding-bottom" "12px"
                , Attr.style "border-bottom" ("1px solid " ++ Style.border)
                , Attr.style "font-family" Style.fontSans
                , Attr.style "font-size" "18px"
                , Attr.style "font-weight" "600"
                , Attr.style "letter-spacing" "0.08em"
                , Attr.style "text-transform" "uppercase"
                , Attr.style "color" Style.accent
                ]
                [ Html.text title ]
            , helpText intro
            ]
            :: questions
        )


type alias Question =
    { name : String
    , label : String
    , help : String
    , required : Required
    , kind : Kind
    }


type Required
    = Required
    | Optional


type Kind
    = ShortText
    | Email
    | LongText
    | SingleChoice (List Choice)
    | MultipleChoiceWithOther (List Choice)


type alias Choice =
    { value : String
    , label : String
    }


aboutYou : List Question
aboutYou =
    [ { name = "first_name", label = "First name", help = "", required = Required, kind = ShortText }
    , { name = "last_name", label = "Last name", help = "", required = Required, kind = ShortText }
    , { name = "email", label = "Email address", help = "", required = Required, kind = Email }
    , { name = "profile"
      , label = "Website or professional profile"
      , help = "LinkedIn, GitHub, personal website, academic profile, etc. You can add several links separated by commas."
      , required = Optional
      , kind = ShortText
      }
    , { name = "city", label = "City you currently live in", help = "", required = Required, kind = ShortText }
    , { name = "career"
      , label = "What stage of your career are you at?"
      , help = ""
      , required = Required
      , kind =
            SingleChoice
                [ { value = "student", label = "Bachelor's or master's student" }
                , { value = "phd", label = "PhD student" }
                , { value = "early", label = "Postdoc or early-career researcher (0–3 years after PhD)" }
                , { value = "mid", label = "Mid-career researcher or professional" }
                , { value = "senior", label = "Senior researcher, professor or professional" }
                ]
      }
    , { name = "institution"
      , label = "Which institution, company or lab do you study or work at?"
      , help = "If you aren't affiliated with any institution or company and aren't a freelancer, write \"Independent\"."
      , required = Required
      , kind = ShortText
      }
    ]


interests : List Question
interests =
    [ { name = "areas"
      , label = "Which areas interest you most?"
      , help = "You can select more than one."
      , required = Required
      , kind =
            MultipleChoiceWithOther
                [ { value = "interp", label = "Interpretability (mechanistic interpretability, representation analysis, etc.)" }
                , { value = "evals", label = "Evaluation (capability evaluations, dangerous capability evals, benchmarking)" }
                , { value = "alignment", label = "Alignment (RLHF, scalable oversight, value alignment)" }
                , { value = "robustness", label = "Robustness and adversarial ML" }
                , { value = "governance", label = "AI governance and policy" }
                , { value = "ethics", label = "AI ethics and social impact" }
                , { value = "security", label = "Cybersecurity for frontier models" }
                , { value = "xrisk", label = "Catastrophic and existential risks" }
                ]
      }
    , { name = "why"
      , label = "Why are you interested in joining the community?"
      , help = "Tell us what motivates you to become part of the community."
      , required = Required
      , kind = LongText
      }
    , { name = "goals"
      , label = "What would you like to get out of the community?"
      , help = "For example: exchanging ideas with other researchers in Sweden, finding a mentor, taking part in a mentorship programme, contributing to a project, or networking ahead of fellowship applications."
      , required = Optional
      , kind = LongText
      }
    , { name = "initiatives"
      , label = "Which community activities interest you most?"
      , help = ""
      , required = Required
      , kind =
            MultipleChoiceWithOther
                [ { value = "meetup", label = "Informal in-person meetups" }
                , { value = "seminars", label = "Research seminars (presentations of papers or work in progress)" }
                , { value = "outreach", label = "Teaching and outreach talks (e.g. seminars for university students)" }
                , { value = "mentorship", label = "Mentorship programme" }
                , { value = "annual", label = "Annual events and workshops in Sweden" }
                , { value = "conf_meetups", label = "Meetups at international conferences" }
                ]
      }
    ]


involvementChoices : List ( Involvement, Choice )
involvementChoices =
    [ ( Participant
      , { value = "participant"
        , label = "As a participating member: I take part in the activities on offer, but don't help organize them."
        }
      )
    , ( Organizer
      , { value = "organizer"
        , label = "As an organizing member: I want to contribute regularly to one or more working groups."
        }
      )
    , ( OccasionalContributor
      , { value = "occasional"
        , label = "As an occasional contributor: I'd like to propose or support individual activities (e.g. mentoring, or proposing a seminar or event) without being involved in the working groups on an ongoing basis."
        }
      )
    ]


involvementView : Html Msg
involvementView =
    Html.fieldset fieldsetStyle
        (questionLegend "How would you like to take part in the community?" Required
            :: helpText "If you choose \"organizing member\" we'll ask which working groups you'd like to join. If you choose \"occasional contributor\" we'll ask about the activities you'd like to contribute to."
            :: List.map
                (\( involvement, choice ) ->
                    choiceRow
                        [ Attr.type_ "radio"
                        , Attr.name "involvement"
                        , Attr.value choice.value
                        , Attr.required True
                        , Html.Events.onCheck (\_ -> SelectedInvolvement involvement)
                        ]
                        choice.label
                )
                involvementChoices
        )


occasionalIntro : String
occasionalIntro =
    "Thanks for being willing to contribute. This section helps us understand how you'd like to contribute, so we can get back to you when opportunities come up that match your interests and skills.\n\nThere's no fixed commitment: the idea is that you only get involved in specific activities, when it makes sense for you."


occasionalQuestions : List Question
occasionalQuestions =
    [ { name = "contrib_types"
      , label = "What kinds of activities would you like to contribute to?"
      , help = "You can select more than one."
      , required = Required
      , kind =
            MultipleChoiceWithOther
                [ { value = "research_seminar", label = "Giving a research seminar about my own work" }
                , { value = "outreach_seminar", label = "Giving an outreach or teaching seminar (e.g. at a university or local event)" }
                , { value = "city_meetup", label = "Proposing or organizing a meetup in my city" }
                , { value = "conf_event", label = "Proposing or organizing an event at an international conference I'm attending" }
                , { value = "mentor", label = "Being a supervisor or mentor in a mentorship programme" }
                , { value = "research_project", label = "Contributing to a collaborative community research project" }
                , { value = "content", label = "Writing content (articles, posts, outreach material)" }
                ]
      }
    , { name = "initiative"
      , label = "Do you already have a specific activity in mind that you'd like to propose or support?"
      , help = "For example: a seminar on a recent paper, a workshop at a conference you're attending, or an outreach talk at a school or university. If so, describe it briefly. If not, feel free to leave this empty."
      , required = Optional
      , kind = LongText
      }
    ]


organizerIntro : String
organizerIntro =
    "This section lists the community's active working groups. Each group has its own area of responsibility and a rough list of activities.\n\nFor each group, you can choose one of these levels of involvement:\n• Coordinating: you're willing to coordinate (or co-coordinate) the group, managing its activities and presenting updates at community meetings.\n• Regular participation: you contribute regularly to the group's activities.\n• Occasional participation: you'd like to contribute now and then, on specific activities or when your skills are especially useful.\n• Not taking part in this group.\n\nYou can choose a different level for each group, for example regular participation in one and occasional in another.\n\nSome groups need more work in their first few months, depending on how urgent their initial goals are."


workingGroup : String -> String -> String -> Question
workingGroup name label help =
    { name = name
    , label = label
    , help = help
    , required = Required
    , kind =
        SingleChoice
            [ { value = "coord", label = "Coordinating (or co-coordinating)" }
            , { value = "stable", label = "Regular participation" }
            , { value = "occasional", label = "Occasional participation" }
            , { value = "none", label = "I don't want to take part in this group" }
            ]
    }


organizerQuestions : List Question
organizerQuestions =
    [ workingGroup "grp_mentorship"
        "Mentorship programme"
        "Designs and runs the community's mentorship programme, connecting people who want to get into AI safety with people who already have experience in the field.\n\nPlanned activities:\n• Defining the programme's roles (supervisors, participants, and possibly secondary supervisors).\n• Defining the projects (type, characteristics, selection criteria).\n• Organizing the programme and its timeline.\n• Selecting projects, supervisors and participants (participants together with the supervisors).\n• Looking into offering compute grants to participants (e.g. BlueDot rapid small grants).\n• Organizing events to present and share the programme's results."
    , workingGroup "grp_governance"
        "Governance, fundraising and finances"
        "Handles the community's formal structure, its financial sustainability and the day-to-day management of its finances.\n\nPlanned activities:\n• Deciding whether, and in what form, to set up an association.\n• Finding funding opportunities and grants (e.g. AI Safety Funding).\n• Preparing and submitting grant applications.\n• If no association is set up, looking into possible fiscal sponsors (e.g. Ashgro, OCEurope).\n• Looking into opening channels for donations (e.g. Manifund).\n• Managing income and expenses, and reporting on them to the community."
    , workingGroup "grp_comms"
        "Communications"
        "Handles how the community presents itself: content, social media channels and incoming messages.\n\nPlanned activities:\n• Preparing content for the website.\n• Choosing and running social media platforms.\n• Creating content for social media.\n• Managing the contact email inbox."
    , workingGroup "grp_infra"
        "Technical infrastructure"
        "Handles the community's digital tools.\n\nPlanned activities:\n• Building and maintaining the website.\n• Managing the web and email domains (including any subdomains and custom email addresses).\n• Running and maintaining the Discord server."
    , workingGroup "grp_community"
        "Community and networking"
        "Handles who is part of the community and how people join: membership rules, finding new members and onboarding.\n\nPlanned activities:\n• Setting the rules and procedure for joining the community.\n• Finding and contacting people who might be interested.\n• Preparing the membership application form.\n• Creating and managing the member database (following the ENAIS model, which distinguishes active contributors, occasional contributors and participants).\n• Handling invitations, membership requests and onboarding of new members (including email templates for invitations, confirmations, etc.)."
    , workingGroup "grp_events"
        "Events"
        "Provides logistical and practical support for the community's events.\n\nPlanned activities:\n• Organizing events in Sweden (handling registrations, finding venues, an email inbox for questions).\n• Helping organize meetups at international conferences.\n• Helping organize seminars for students and researchers.\n• Keeping the community calendar up to date.\n• Note: any community member can propose and lead an event, not just the events group. The group mainly handles the organizational side, supporting whoever proposed the event in making it happen."
    , workingGroup "grp_seminars"
        "Seminars"
        "Runs seminar series for researchers, where research results are presented.\n\nPlanned activities:\n• Scheduling the seminar series.\n• Finding and contacting speakers who want to present their work.\n• Running and moderating the seminars."
    , workingGroup "grp_outreach"
        "Teaching and outreach"
        "Handles outreach in education and to the public, including seminars for students.\n\nPlanned activities:\n• Preparing teaching materials.\n• Giving seminars at universities.\n• Giving outreach talks at local events.\n• Note: teaching materials don't need to be a single shared package. Everyone can run their own seminars as they like, and where there's room to collaborate, material can be combined, shared (always crediting who made it) and presented independently."
    , { name = "hours_range"
      , label = "How many hours a month would you like to give to AI Safety Sweden?"
      , help = ""
      , required = Required
      , kind =
            SingleChoice
                [ { value = "h0", label = "Less than 2 hours" }
                , { value = "h1", label = "2–5 hours" }
                , { value = "h2", label = "5–10 hours" }
                , { value = "h3", label = "10–20 hours" }
                , { value = "h4", label = "More than 20 hours" }
                ]
      }
    , { name = "experience"
      , label = "Do you have relevant experience you'd like to tell us about?"
      , help = "For example: I've coordinated similar communities or groups, I have fundraising experience, I've run websites or Discord servers, or I've organized academic events."
      , required = Optional
      , kind = LongText
      }
    , { name = "anything_else"
      , label = "Is there anything else you'd like to tell us?"
      , help = ""
      , required = Optional
      , kind = LongText
      }
    ]


isRequired : Required -> Bool
isRequired required =
    case required of
        Required ->
            True

        Optional ->
            False


questionView : Dict String (Set String) -> Question -> Html Msg
questionView checked question =
    case question.kind of
        ShortText ->
            textQuestion question
                (Html.input
                    (Attr.type_ "text"
                        :: Attr.id question.name
                        :: Attr.name question.name
                        :: Attr.required (isRequired question.required)
                        :: Attr.maxlength 300
                        :: inputStyle
                    )
                    []
                )

        Email ->
            textQuestion question
                (Html.input
                    (Attr.type_ "email"
                        :: Attr.id question.name
                        :: Attr.name question.name
                        :: Attr.required (isRequired question.required)
                        :: Attr.attribute "autocomplete" "email"
                        :: inputStyle
                    )
                    []
                )

        LongText ->
            textQuestion question
                (Html.textarea
                    (Attr.id question.name
                        :: Attr.name question.name
                        :: Attr.required (isRequired question.required)
                        :: Attr.maxlength 8000
                        :: Attr.rows 4
                        :: Attr.style "resize" "vertical"
                        :: inputStyle
                    )
                    []
                )

        SingleChoice choices ->
            Html.fieldset fieldsetStyle
                (questionLegend question.label question.required
                    :: helpText question.help
                    :: List.map
                        (\choice ->
                            choiceRow
                                [ Attr.type_ "radio"
                                , Attr.name question.name
                                , Attr.value choice.value
                                , Attr.required (isRequired question.required)
                                ]
                                choice.label
                        )
                        choices
                )

        MultipleChoiceWithOther choices ->
            let
                checkedValues =
                    Maybe.withDefault Set.empty (Dict.get question.name checked)

                -- Browsers can't require "at least one" of a group of checkboxes, so each checkbox is required until one is checked.
                required =
                    isRequired question.required && Set.isEmpty checkedValues

                checkbox value =
                    [ Attr.type_ "checkbox"
                    , Attr.name question.name
                    , Attr.value value
                    , Attr.required required
                    , Html.Events.onCheck (ToggledCheckbox question.name value)
                    ]
            in
            Html.fieldset fieldsetStyle
                (questionLegend question.label question.required
                    :: helpText question.help
                    :: List.map (\choice -> choiceRow (checkbox choice.value) choice.label) choices
                    ++ [ Html.div
                            [ Attr.style "display" "flex"
                            , Attr.style "flex-wrap" "wrap"
                            , Attr.style "align-items" "center"
                            , Attr.style "gap" "8px 12px"
                            ]
                            [ choiceRow (checkbox "other") "Other:"
                            , Html.input
                                (Attr.type_ "text"
                                    :: Attr.name (question.name ++ "_other")
                                    :: Attr.attribute "aria-label" (question.label ++ " (other)")
                                    :: Attr.maxlength 300
                                    :: Attr.style "flex" "1 1 200px"
                                    :: Attr.style "width" "auto"
                                    :: inputStyle
                                )
                                []
                            ]
                       ]
                )


textQuestion : Question -> Html msg -> Html msg
textQuestion question input =
    Html.div
        [ Attr.style "display" "flex"
        , Attr.style "flex-direction" "column"
        , Attr.style "gap" "8px"
        ]
        [ Html.label [ Attr.for question.name ] [ questionTitle question.label question.required ]
        , helpText question.help
        , input
        ]


questionLegend : String -> Required -> Html msg
questionLegend label required =
    Html.legend
        [ Attr.style "padding" "0"
        , Attr.style "margin-bottom" "8px"
        ]
        [ questionTitle label required ]


questionTitle : String -> Required -> Html msg
questionTitle label required =
    Html.span
        [ Attr.style "font-size" "18px"
        , Attr.style "font-weight" "600"
        , Attr.style "color" Style.textStrong
        ]
        (case required of
            Required ->
                [ Html.text label
                , Html.span [ Attr.style "color" Style.accent, Attr.attribute "aria-hidden" "true" ] [ Html.text " *" ]
                ]

            Optional ->
                [ Html.text label ]
        )


helpText : String -> Html msg
helpText help =
    if help == "" then
        Html.text ""

    else
        Html.p
            [ Attr.style "margin" "8px 0"
            , Attr.style "white-space" "pre-line"
            , Attr.style "font-size" "16px"
            , Attr.style "line-height" "1.6"
            , Attr.style "color" Style.textMuted
            ]
            [ Html.text help ]


fieldsetStyle : List (Html.Attribute msg)
fieldsetStyle =
    [ Attr.style "margin" "0"
    , Attr.style "padding" "0"
    , Attr.style "border" "none"
    , Attr.style "min-width" "0"
    , Attr.style "display" "flex"
    , Attr.style "flex-direction" "column"
    , Attr.style "gap" "4px"
    ]


choiceRow : List (Html.Attribute msg) -> String -> Html msg
choiceRow inputAttributes label =
    Html.label
        [ Attr.style "display" "flex"
        , Attr.style "align-items" "flex-start"
        , Attr.style "gap" "12px"
        , Attr.style "padding" "8px 0"
        , Attr.style "font-size" "17px"
        , Attr.style "line-height" "1.45"
        , Attr.style "cursor" "pointer"
        ]
        [ Html.input
            (Attr.style "margin" "3px 0 0"
                :: Attr.style "width" "20px"
                :: Attr.style "height" "20px"
                :: Attr.style "flex" "none"
                :: Attr.style "accent-color" Style.accent
                :: inputAttributes
            )
            []
        , Html.span [] [ Html.text label ]
        ]


inputStyle : List (Html.Attribute msg)
inputStyle =
    [ Attr.style "width" "100%"
    , Attr.style "box-sizing" "border-box"
    , Attr.style "padding" "12px 14px"
    , Attr.style "border" ("1px solid " ++ Style.borderStrong)
    , Attr.style "border-radius" "10px"
    , Attr.style "background" Style.background
    , Attr.style "color" Style.textStrong
    , Attr.style "font" "inherit"
    , Attr.style "font-size" "17px"
    ]


{-| Hidden from people. Spam bots tend to fill in every field, and the Netlify function drops submissions where this is filled in.
-}
honeypot : Html msg
honeypot =
    Html.div
        [ Attr.attribute "aria-hidden" "true"
        , Attr.style "position" "absolute"
        , Attr.style "left" "-10000px"
        ]
        [ Html.label []
            [ Html.text "Leave this empty"
            , Html.input [ Attr.type_ "text", Attr.name "website", Attr.tabindex -1, Attr.attribute "autocomplete" "off" ] []
            ]
        ]


consentView : Html msg
consentView =
    Html.div
        [ Attr.style "padding" "20px"
        , Attr.style "border" ("1px solid " ++ Style.borderStrong)
        , Attr.style "border-radius" "16px"
        , Attr.style "background" Style.surface
        ]
        [ choiceRow
            [ Attr.type_ "checkbox"
            , Attr.name "privacy"
            , Attr.value "accepted"
            , Attr.required True
            ]
            "I agree to AI Safety Sweden storing and processing the personal data in this form in order to handle my membership. *"
        ]


submitButton : Html msg
submitButton =
    Html.button
        [ Attr.type_ "submit"
        , Attr.style "align-self" "flex-start"
        , Attr.style "padding" "18px 32px"
        , Attr.style "border" "none"
        , Attr.style "border-radius" "16px"
        , Attr.style "background" Style.accent
        , Attr.style "color" Style.background
        , Attr.style "font" "inherit"
        , Attr.style "font-size" "20px"
        , Attr.style "font-weight" "600"
        , Attr.style "cursor" "pointer"
        ]
        [ Html.text "Sign up" ]
