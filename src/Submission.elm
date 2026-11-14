module Submission exposing (Answer(..), Submission, answerText, decoder, field, questionLabel)

{-| A signup from the form at aisafetysweden.se/join. The website's Netlify function
(netlify/functions/join.mjs in the website repo) sends it here as JSON:

    { "secret": "...", "submittedAt": "2026-11-14T13:00:00.000Z", "answers": { "first_name": "Ada", "areas": [ "interp", "other" ] } }

-}

import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Time


type alias Submission =
    { submittedAt : Time.Posix
    , answers : List ( String, Answer )
    }


type Answer
    = TextAnswer String
    | ListAnswer (List String)


decoder : Decoder { secret : String, submission : Submission }
decoder =
    Decode.map3
        (\secret submittedAt answers -> { secret = secret, submission = { submittedAt = submittedAt, answers = answers } })
        (Decode.field "secret" Decode.string)
        (Decode.field "submittedAt" Iso8601.decoder)
        (Decode.field "answers"
            (Decode.keyValuePairs
                (Decode.oneOf
                    [ Decode.map TextAnswer Decode.string
                    , Decode.map ListAnswer (Decode.list Decode.string)
                    ]
                )
                |> Decode.map orderAnswers
            )
        )


{-| JSON objects don't keep their order, so put answers back in the order the form asks them.
-}
orderAnswers : List ( String, Answer ) -> List ( String, Answer )
orderAnswers answers =
    let
        position : String -> Int
        position name =
            indexOf name (List.map .name questions)
    in
    List.sortBy (\( name, _ ) -> position name) answers


indexOf : a -> List a -> Int
indexOf item list =
    case list of
        first :: rest ->
            if first == item then
                0

            else
                1 + indexOf item rest

        [] ->
            0


field : String -> Submission -> String
field name submission =
    case List.filter (\( answerName, _ ) -> answerName == name) submission.answers of
        ( _, answer ) :: _ ->
            answerText name answer

        [] ->
            ""


questionLabel : String -> String
questionLabel name =
    case List.filter (\question -> question.name == name) questions of
        question :: _ ->
            question.label

        [] ->
            name


answerText : String -> Answer -> String
answerText name answer =
    let
        optionLabel : String -> String
        optionLabel value =
            case List.filter (\question -> question.name == name) questions of
                question :: _ ->
                    case List.filter (\( optionValue, _ ) -> optionValue == value) question.options of
                        ( _, label ) :: _ ->
                            label

                        [] ->
                            value

                [] ->
                    value
    in
    case answer of
        TextAnswer text ->
            optionLabel text

        ListAnswer values ->
            List.map optionLabel values |> String.join ", "


type alias Question =
    { name : String
    , label : String
    , options : List ( String, String )
    }


workingGroupOptions : List ( String, String )
workingGroupOptions =
    [ ( "coord", "Coordinating" )
    , ( "stable", "Regular" )
    , ( "occasional", "Occasional" )
    , ( "none", "Not taking part" )
    ]


{-| The questions on the website's form (app/Route/Join.elm), with shorter labels.
-}
questions : List Question
questions =
    [ { name = "first_name", label = "First name", options = [] }
    , { name = "last_name", label = "Last name", options = [] }
    , { name = "email", label = "Email", options = [] }
    , { name = "profile", label = "Website or profile", options = [] }
    , { name = "city", label = "City", options = [] }
    , { name = "career"
      , label = "Career stage"
      , options =
            [ ( "student", "Bachelor's or master's student" )
            , ( "phd", "PhD student" )
            , ( "early", "Postdoc or early-career researcher" )
            , ( "mid", "Mid-career researcher or professional" )
            , ( "senior", "Senior researcher, professor or professional" )
            ]
      }
    , { name = "institution", label = "Institution", options = [] }
    , { name = "areas"
      , label = "Areas of interest"
      , options =
            [ ( "interp", "Interpretability" )
            , ( "evals", "Evaluation" )
            , ( "alignment", "Alignment" )
            , ( "robustness", "Robustness and adversarial ML" )
            , ( "governance", "AI governance and policy" )
            , ( "ethics", "AI ethics and social impact" )
            , ( "security", "Cybersecurity for frontier models" )
            , ( "xrisk", "Catastrophic and existential risks" )
            , ( "other", "Other" )
            ]
      }
    , { name = "areas_other", label = "Areas of interest (other)", options = [] }
    , { name = "why", label = "Why join", options = [] }
    , { name = "goals", label = "What they'd like to get out of it", options = [] }
    , { name = "initiatives"
      , label = "Activities of interest"
      , options =
            [ ( "meetup", "Informal meetups" )
            , ( "seminars", "Research seminars" )
            , ( "outreach", "Teaching and outreach talks" )
            , ( "mentorship", "Mentorship programme" )
            , ( "annual", "Annual events and workshops" )
            , ( "conf_meetups", "Meetups at international conferences" )
            , ( "other", "Other" )
            ]
      }
    , { name = "initiatives_other", label = "Activities of interest (other)", options = [] }
    , { name = "involvement"
      , label = "How they'd like to take part"
      , options =
            [ ( "participant", "Participating member" )
            , ( "organizer", "Organizing member" )
            , ( "occasional", "Occasional contributor" )
            ]
      }
    , { name = "contrib_types"
      , label = "Would contribute to"
      , options =
            [ ( "research_seminar", "Research seminar on own work" )
            , ( "outreach_seminar", "Outreach or teaching seminar" )
            , ( "city_meetup", "Meetup in their city" )
            , ( "conf_event", "Event at an international conference" )
            , ( "mentor", "Supervisor or mentor" )
            , ( "research_project", "Collaborative research project" )
            , ( "content", "Writing content" )
            , ( "other", "Other" )
            ]
      }
    , { name = "contrib_types_other", label = "Would contribute to (other)", options = [] }
    , { name = "initiative", label = "Activity in mind", options = [] }
    , { name = "grp_mentorship", label = "Group: Mentorship programme", options = workingGroupOptions }
    , { name = "grp_governance", label = "Group: Governance, fundraising and finances", options = workingGroupOptions }
    , { name = "grp_comms", label = "Group: Communications", options = workingGroupOptions }
    , { name = "grp_infra", label = "Group: Technical infrastructure", options = workingGroupOptions }
    , { name = "grp_community", label = "Group: Community and networking", options = workingGroupOptions }
    , { name = "grp_events", label = "Group: Events", options = workingGroupOptions }
    , { name = "grp_seminars", label = "Group: Seminars", options = workingGroupOptions }
    , { name = "grp_outreach", label = "Group: Teaching and outreach", options = workingGroupOptions }
    , { name = "hours_range"
      , label = "Hours a month"
      , options =
            [ ( "h0", "Less than 2" )
            , ( "h1", "2–5" )
            , ( "h2", "5–10" )
            , ( "h3", "10–20" )
            , ( "h4", "More than 20" )
            ]
      }
    , { name = "experience", label = "Relevant experience", options = [] }
    , { name = "anything_else", label = "Anything else", options = [] }
    , { name = "privacy", label = "Privacy consent", options = [ ( "accepted", "Accepted" ) ] }
    ]
