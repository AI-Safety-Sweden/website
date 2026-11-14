module LoginForm exposing
    ( LoginForm
    , Msg
    , emailNotAllowed
    , initWithEmail
    , initWithRecoveryPassword
    , invalidCode
    , loginCodeLength
    , maxLoginAttempts
    , rateLimited
    , recoveryPasswordInvalid
    , update
    , view
    )

{-| Logging in by typing in a code sent by email, as in at-chat. Only emails already in the user
table get a code; there's no sign up.
-}

import Effect.Command as Command exposing (Command, FrontendOnly)
import EmailAddress exposing (EmailAddress)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events
import Style


type LoginForm
    = EnterEmail EnterEmail2
    | EnterLoginCode EnterLoginCode2
    | EnterRecoveryPassword EnterRecoveryPassword2


type alias EnterEmail2 =
    { email : String
    , pressedSubmit : Bool
    , problem : Maybe EmailProblem
    }


type EmailProblem
    = RateLimited
    | NotAllowed


type alias EnterLoginCode2 =
    { sentTo : EmailAddress
    , code : String
    , checking : Maybe Int
    , invalidCodes : List Int
    }


type alias EnterRecoveryPassword2 =
    { password : String
    , checking : Bool
    , invalid : Bool
    }


type Msg
    = TypedEmail String
    | PressedSubmitEmail
    | TypedLoginCode String
    | PressedCancelLogin
    | TypedRecoveryPassword String
    | PressedSubmitRecoveryPassword


loginCodeLength : number
loginCodeLength =
    8


maxLoginAttempts : number
maxLoginAttempts =
    10


initWithEmail : LoginForm
initWithEmail =
    EnterEmail { email = "", pressedSubmit = False, problem = Nothing }


initWithRecoveryPassword : LoginForm
initWithRecoveryPassword =
    EnterRecoveryPassword { password = "", checking = False, invalid = False }


update :
    (EmailAddress -> Command FrontendOnly toBackend Msg)
    -> (Int -> Command FrontendOnly toBackend Msg)
    -> (String -> Command FrontendOnly toBackend Msg)
    -> Msg
    -> LoginForm
    -> ( LoginForm, Command FrontendOnly toBackend Msg )
update onSubmitEmail onSubmitLoginCode onSubmitRecoveryPassword msg model =
    case msg of
        TypedEmail text ->
            case model of
                EnterEmail form ->
                    ( EnterEmail { form | email = text, problem = Nothing }, Command.none )

                _ ->
                    ( model, Command.none )

        PressedSubmitEmail ->
            case model of
                EnterEmail form ->
                    case EmailAddress.fromString (String.trim form.email) of
                        Just email ->
                            ( EnterLoginCode { sentTo = email, code = "", checking = Nothing, invalidCodes = [] }
                            , onSubmitEmail email
                            )

                        Nothing ->
                            ( EnterEmail { form | pressedSubmit = True }, Command.none )

                _ ->
                    ( model, Command.none )

        TypedLoginCode text ->
            case model of
                EnterLoginCode form ->
                    let
                        code : String
                        code =
                            String.filter Char.isDigit text |> String.left loginCodeLength
                    in
                    case ( String.length code == loginCodeLength, String.toInt code ) of
                        ( True, Just int ) ->
                            if List.member int form.invalidCodes then
                                ( EnterLoginCode { form | code = code }, Command.none )

                            else
                                ( EnterLoginCode { form | code = code, checking = Just int }, onSubmitLoginCode int )

                        _ ->
                            ( EnterLoginCode { form | code = code }, Command.none )

                _ ->
                    ( model, Command.none )

        PressedCancelLogin ->
            ( initWithEmail, Command.none )

        TypedRecoveryPassword text ->
            case model of
                EnterRecoveryPassword form ->
                    ( EnterRecoveryPassword { form | password = text, invalid = False }, Command.none )

                _ ->
                    ( model, Command.none )

        PressedSubmitRecoveryPassword ->
            case model of
                EnterRecoveryPassword form ->
                    ( EnterRecoveryPassword { form | checking = True }, onSubmitRecoveryPassword form.password )

                _ ->
                    ( model, Command.none )


rateLimited : LoginForm -> LoginForm
rateLimited model =
    case model of
        EnterLoginCode form ->
            EnterEmail { email = EmailAddress.toString form.sentTo, pressedSubmit = False, problem = Just RateLimited }

        _ ->
            model


emailNotAllowed : LoginForm -> LoginForm
emailNotAllowed model =
    case model of
        EnterLoginCode form ->
            EnterEmail { email = EmailAddress.toString form.sentTo, pressedSubmit = False, problem = Just NotAllowed }

        _ ->
            model


invalidCode : Int -> LoginForm -> LoginForm
invalidCode code model =
    case model of
        EnterLoginCode form ->
            EnterLoginCode
                { form
                    | invalidCodes = code :: form.invalidCodes
                    , checking =
                        if form.checking == Just code then
                            Nothing

                        else
                            form.checking
                }

        _ ->
            model


recoveryPasswordInvalid : LoginForm -> LoginForm
recoveryPasswordInvalid model =
    case model of
        EnterRecoveryPassword form ->
            EnterRecoveryPassword { form | checking = False, invalid = True }

        _ ->
            model


view : LoginForm -> Html Msg
view model =
    Html.div
        [ Attr.style "max-width" "400px"
        , Attr.style "margin" "80px auto"
        , Attr.style "padding" "0 20px"
        ]
        [ Html.h1 [ Attr.style "margin" "0 0 24px", Attr.style "font-size" "28px" ] [ Html.text "AI Safety Sweden admin" ]
        , case model of
            EnterEmail form ->
                Html.form
                    [ Html.Events.onSubmit PressedSubmitEmail, Attr.novalidate True ]
                    [ label "login_email" "Email"
                    , Html.input
                        (Attr.id "login_email"
                            :: Attr.type_ "email"
                            :: Attr.value form.email
                            :: Attr.attribute "autocomplete" "email"
                            :: Html.Events.onInput TypedEmail
                            :: inputStyle
                        )
                        []
                    , case ( form.problem, form.pressedSubmit && EmailAddress.fromString (String.trim form.email) == Nothing ) of
                        ( _, True ) ->
                            errorText "That doesn't look like an email address"

                        ( Just RateLimited, False ) ->
                            errorText "Too many login attempts. Wait a few minutes and try again."

                        ( Just NotAllowed, False ) ->
                            errorText "That email isn't allowed to log in. Ask an admin to add you."

                        ( Nothing, False ) ->
                            Html.text ""
                    , Html.div [ Attr.style "margin-top" "16px" ] [ submitButton "Send login code" ]
                    ]

            EnterLoginCode form ->
                Html.div []
                    [ Html.p [] [ Html.text ("We sent a code to " ++ EmailAddress.toString form.sentTo ++ ". Type it in below.") ]
                    , label "login_code" "Login code"
                    , Html.input
                        (Attr.id "login_code"
                            :: Attr.value form.code
                            :: Attr.attribute "inputmode" "numeric"
                            :: Attr.attribute "autocomplete" "one-time-code"
                            :: Html.Events.onInput TypedLoginCode
                            :: Attr.style "letter-spacing" "0.3em"
                            :: inputStyle
                        )
                        []
                    , case String.toInt form.code of
                        Just int ->
                            if List.member int form.invalidCodes then
                                errorText "That code isn't right"

                            else if form.checking == Just int then
                                Html.p [ Attr.style "color" Style.textFaint ] [ Html.text "Checking…" ]

                            else
                                Html.text ""

                        Nothing ->
                            Html.text ""
                    , Html.div [ Attr.style "margin-top" "16px" ] [ Style.smallButton PressedCancelLogin "Use a different email" ]
                    ]

            EnterRecoveryPassword form ->
                Html.form
                    [ Html.Events.onSubmit PressedSubmitRecoveryPassword ]
                    [ Html.p [] [ Html.text "Login emails aren't set up yet, so log in with the recovery password, then add a Postmark API key." ]
                    , label "login_password" "Recovery password"
                    , Html.input
                        (Attr.id "login_password"
                            :: Attr.type_ "password"
                            :: Attr.value form.password
                            :: Html.Events.onInput TypedRecoveryPassword
                            :: inputStyle
                        )
                        []
                    , if form.invalid then
                        errorText "Wrong password"

                      else
                        Html.text ""
                    , Html.div [ Attr.style "margin-top" "16px" ]
                        [ if form.checking then
                            Html.p [ Attr.style "color" Style.textFaint ] [ Html.text "Checking…" ]

                          else
                            submitButton "Log in"
                        ]
                    ]
        ]


label : String -> String -> Html msg
label for text =
    Html.label
        [ Attr.for for
        , Attr.style "display" "block"
        , Attr.style "margin-bottom" "6px"
        , Attr.style "font-weight" "600"
        ]
        [ Html.text text ]


inputStyle : List (Html.Attribute msg)
inputStyle =
    [ Attr.style "width" "100%"
    , Attr.style "box-sizing" "border-box"
    , Attr.style "padding" "10px 12px"
    , Attr.style "border" ("1px solid " ++ Style.borderStrong)
    , Attr.style "border-radius" "8px"
    , Attr.style "font" "inherit"
    , Attr.style "font-size" "17px"
    ]


errorText : String -> Html msg
errorText text =
    Html.p [ Attr.style "color" Style.error, Attr.style "margin" "8px 0 0" ] [ Html.text text ]


submitButton : String -> Html msg
submitButton text =
    Html.button
        [ Attr.type_ "submit"
        , Attr.style "padding" "10px 18px"
        , Attr.style "border" "none"
        , Attr.style "border-radius" "8px"
        , Attr.style "background" Style.accent
        , Attr.style "color" Style.background
        , Attr.style "font" "inherit"
        , Attr.style "font-weight" "600"
        , Attr.style "cursor" "pointer"
        ]
        [ Html.text text ]
