module Frontend exposing (app, app_)

import Browser exposing (UrlRequest(..))
import Browser.Navigation
import Effect.Browser
import Effect.Browser.Navigation as Navigation exposing (Key)
import Effect.Command as Command exposing (Command, FrontendOnly)
import Effect.Lamdera as Lamdera
import Effect.Subscription as Subscription
import Effect.Task as Task
import Effect.Time as Time
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events
import Id exposing (Id, SubmissionId)
import Lamdera as LamderaCore
import LoginForm
import Postmark
import SeqDict
import Style
import Submission exposing (Submission)
import Types exposing (AdminData, FrontendModel, FrontendMsg(..), LoggedInModel, LoginType(..), Page(..), ToBackend(..), ToFrontend(..))
import Url exposing (Url)
import UserTable


app :
    { init : Url -> Browser.Navigation.Key -> ( FrontendModel, Cmd FrontendMsg )
    , view : FrontendModel -> Effect.Browser.Document FrontendMsg
    , update : FrontendMsg -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
    , updateFromBackend : ToFrontend -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
    , subscriptions : FrontendModel -> Sub FrontendMsg
    , onUrlRequest : UrlRequest -> FrontendMsg
    , onUrlChange : Url -> FrontendMsg
    }
app =
    Lamdera.frontend LamderaCore.sendToBackend app_


app_ :
    { init : Url -> Key -> ( FrontendModel, Command FrontendOnly ToBackend FrontendMsg )
    , onUrlRequest : UrlRequest -> FrontendMsg
    , onUrlChange : Url -> FrontendMsg
    , update : FrontendMsg -> FrontendModel -> ( FrontendModel, Command FrontendOnly ToBackend FrontendMsg )
    , updateFromBackend : ToFrontend -> FrontendModel -> ( FrontendModel, Command FrontendOnly ToBackend FrontendMsg )
    , subscriptions : FrontendModel -> Subscription.Subscription FrontendOnly FrontendMsg
    , view : FrontendModel -> Effect.Browser.Document FrontendMsg
    }
app_ =
    { init = init
    , onUrlRequest = UrlClicked
    , onUrlChange = UrlChanged
    , update = update
    , updateFromBackend = updateFromBackend
    , subscriptions = \_ -> Subscription.none
    , view = view
    }


init : Url -> Key -> ( FrontendModel, Command FrontendOnly ToBackend FrontendMsg )
init _ key =
    ( { key = key, zone = Time.utc, time = Time.millisToPosix 0, page = CheckingLogin }
    , Command.batch
        [ Lamdera.sendToBackend CheckLoginRequest
        , Task.perform GotZone Time.here
        , Task.perform GotTime Time.now
        ]
    )


update : FrontendMsg -> FrontendModel -> ( FrontendModel, Command FrontendOnly ToBackend FrontendMsg )
update msg model =
    case msg of
        UrlClicked urlRequest ->
            case urlRequest of
                Internal url ->
                    ( model, Navigation.pushUrl model.key (Url.toString url) )

                External url ->
                    ( model, Navigation.load url )

        UrlChanged _ ->
            ( model, Command.none )

        GotZone zone ->
            ( { model | zone = zone }, Command.none )

        GotTime time ->
            ( { model | time = time }, Command.none )

        LoginFormMsg loginFormMsg ->
            case model.page of
                NotLoggedIn loginType loginForm ->
                    let
                        ( loginForm2, cmd ) =
                            LoginForm.update
                                (\email -> Lamdera.sendToBackend (GetLoginCodeRequest email))
                                (\code -> Lamdera.sendToBackend (LoginWithCodeRequest code))
                                (\password -> Lamdera.sendToBackend (LoginWithRecoveryPasswordRequest password))
                                loginFormMsg
                                loginForm
                    in
                    ( { model | page = NotLoggedIn loginType loginForm2 }, Command.map identity LoginFormMsg cmd )

                CheckingLogin ->
                    ( model, Command.none )

                LoggedIn _ ->
                    ( model, Command.none )

        PressedLogOut ->
            ( model, Lamdera.sendToBackend LogOutRequest )

        UserTableMsg userTableMsg ->
            updateLoggedIn
                (\loggedIn ->
                    let
                        ( userTable, cmd ) =
                            UserTable.update loggedIn.users userTableMsg loggedIn.userTable
                    in
                    ( { loggedIn | userTable = userTable, userTableError = Nothing }, Command.map identity UserTableMsg cmd )
                )
                model

        PressedSaveUserChanges ->
            updateLoggedIn
                (\loggedIn ->
                    let
                        userTable =
                            UserTable.applyEditingCell loggedIn.users loggedIn.userTable

                        changes : UserTable.UserChanges
                        changes =
                            { changedUsers = userTable.changedUsers
                            , newUsers = userTable.newUsers
                            , deletedUsers = userTable.deletedUsers
                            }
                    in
                    case UserTable.applyChanges model.time loggedIn.userId changes loggedIn.users of
                        Ok _ ->
                            ( { loggedIn | userTable = UserTable.init, userTableError = Nothing }
                            , Lamdera.sendToBackend (ChangeUsersRequest changes)
                            )

                        Err error ->
                            ( { loggedIn | userTable = userTable, userTableError = Just error }, Command.none )
                )
                model

        PressedSubmission submissionId ->
            updateLoggedIn
                (\loggedIn ->
                    ( { loggedIn
                        | expandedSubmission =
                            if loggedIn.expandedSubmission == Just submissionId then
                                Nothing

                            else
                                Just submissionId
                        , confirmDeleteSubmission = Nothing
                      }
                    , Command.none
                    )
                )
                model

        PressedDeleteSubmission submissionId ->
            updateLoggedIn (\loggedIn -> ( { loggedIn | confirmDeleteSubmission = Just submissionId }, Command.none )) model

        PressedConfirmDeleteSubmission submissionId ->
            updateLoggedIn
                (\loggedIn ->
                    ( { loggedIn | confirmDeleteSubmission = Nothing }
                    , Lamdera.sendToBackend (DeleteSubmissionRequest submissionId)
                    )
                )
                model

        PressedCancelDeleteSubmission ->
            updateLoggedIn (\loggedIn -> ( { loggedIn | confirmDeleteSubmission = Nothing }, Command.none )) model

        TypedPostmarkKey text ->
            updateLoggedIn (\loggedIn -> ( { loggedIn | postmarkKeyInput = text }, Command.none )) model

        PressedSavePostmarkKey ->
            updateLoggedIn
                (\loggedIn ->
                    ( { loggedIn | postmarkKeyInput = "" }
                    , Lamdera.sendToBackend (SetPostmarkKeyRequest (Postmark.apiKey (String.trim loggedIn.postmarkKeyInput)))
                    )
                )
                model


updateLoggedIn :
    (LoggedInModel -> ( LoggedInModel, Command FrontendOnly ToBackend FrontendMsg ))
    -> FrontendModel
    -> ( FrontendModel, Command FrontendOnly ToBackend FrontendMsg )
updateLoggedIn func model =
    case model.page of
        LoggedIn loggedIn ->
            let
                ( loggedIn2, cmd ) =
                    func loggedIn
            in
            ( { model | page = LoggedIn loggedIn2 }, cmd )

        CheckingLogin ->
            ( model, Command.none )

        NotLoggedIn _ _ ->
            ( model, Command.none )


updateLoginForm : (LoginForm.LoginForm -> LoginForm.LoginForm) -> FrontendModel -> FrontendModel
updateLoginForm func model =
    case model.page of
        NotLoggedIn loginType loginForm ->
            { model | page = NotLoggedIn loginType (func loginForm) }

        CheckingLogin ->
            model

        LoggedIn _ ->
            model


loggedInPage : AdminData -> Page
loggedInPage data =
    LoggedIn
        { userId = data.userId
        , users = data.users
        , submissions = data.submissions
        , postmarkKeySet = data.postmarkKeySet
        , userTable = UserTable.init
        , userTableError = Nothing
        , expandedSubmission = Nothing
        , confirmDeleteSubmission = Nothing
        , postmarkKeyInput = ""
        }


updateFromBackend : ToFrontend -> FrontendModel -> ( FrontendModel, Command FrontendOnly ToBackend FrontendMsg )
updateFromBackend msg model =
    case msg of
        CheckLoginResponse (Ok data) ->
            ( { model | page = loggedInPage data }, Command.none )

        CheckLoginResponse (Err loginType) ->
            ( { model
                | page =
                    NotLoggedIn
                        loginType
                        (case loginType of
                            LoginWithEmail ->
                                LoginForm.initWithEmail

                            LoginWithRecoveryPassword ->
                                LoginForm.initWithRecoveryPassword
                        )
              }
            , Command.none
            )

        GetLoginCodeRateLimited ->
            ( updateLoginForm LoginForm.rateLimited model, Command.none )

        EmailNotAllowedResponse ->
            ( updateLoginForm LoginForm.emailNotAllowed model, Command.none )

        LoginWithCodeResponse (Ok data) ->
            ( { model | page = loggedInPage data }, Command.none )

        LoginWithCodeResponse (Err code) ->
            ( updateLoginForm (LoginForm.invalidCode code) model, Command.none )

        RecoveryPasswordInvalidResponse ->
            ( updateLoginForm LoginForm.recoveryPasswordInvalid model, Command.none )

        LoggedOutResponse ->
            ( { model | page = CheckingLogin }, Lamdera.sendToBackend CheckLoginRequest )

        UsersChanged users ->
            updateLoggedIn (\loggedIn -> ( { loggedIn | users = users }, Command.none )) model

        ChangeUsersRejected error ->
            updateLoggedIn (\loggedIn -> ( { loggedIn | userTableError = Just error }, Command.none )) model

        SubmissionAdded submissionId submission ->
            updateLoggedIn
                (\loggedIn -> ( { loggedIn | submissions = SeqDict.insert submissionId submission loggedIn.submissions }, Command.none ))
                model

        SubmissionDeleted submissionId ->
            updateLoggedIn
                (\loggedIn -> ( { loggedIn | submissions = SeqDict.remove submissionId loggedIn.submissions }, Command.none ))
                model

        PostmarkKeyChanged isSet ->
            updateLoggedIn (\loggedIn -> ( { loggedIn | postmarkKeySet = isSet }, Command.none )) model


view : FrontendModel -> Effect.Browser.Document FrontendMsg
view model =
    { title = "AI Safety Sweden admin"
    , body =
        [ Html.div
            [ Attr.style "font-family" "'IBM Plex Sans', system-ui, sans-serif"
            , Attr.style "color" Style.textStrong
            , Attr.style "background" Style.background
            , Attr.style "min-height" "100vh"
            , Attr.style "line-height" "1.5"
            ]
            [ case model.page of
                CheckingLogin ->
                    Html.p [ Attr.style "padding" "40px", Attr.style "color" Style.textFaint ] [ Html.text "Loading…" ]

                NotLoggedIn _ loginForm ->
                    LoginForm.view loginForm |> Html.map LoginFormMsg

                LoggedIn loggedIn ->
                    loggedInView model.zone loggedIn
            ]
        ]
    }


loggedInView : Time.Zone -> LoggedInModel -> Html FrontendMsg
loggedInView zone model =
    Html.div
        [ Attr.style "max-width" "1100px"
        , Attr.style "margin" "0 auto"
        , Attr.style "padding" "24px 20px 80px"
        ]
        [ Html.div
            [ Attr.style "display" "flex"
            , Attr.style "justify-content" "space-between"
            , Attr.style "align-items" "center"
            , Attr.style "gap" "16px"
            ]
            [ Html.h1 [ Attr.style "margin" "0", Attr.style "font-size" "26px" ] [ Html.text "AI Safety Sweden admin" ]
            , Html.div [ Attr.style "display" "flex", Attr.style "align-items" "center", Attr.style "gap" "12px" ]
                [ case SeqDict.get model.userId model.users of
                    Just user ->
                        Html.span [ Attr.style "color" Style.textFaint ] [ Html.text user.name ]

                    Nothing ->
                        Html.text ""
                , Style.smallButton PressedLogOut "Log out"
                ]
            ]
        , if model.postmarkKeySet then
            Html.text ""

          else
            Html.p
                [ Attr.style "padding" "12px 16px"
                , Attr.style "background" "#F6EDC9"
                , Attr.style "border-radius" "8px"
                ]
                [ Html.text "Login emails aren't set up. Add a Postmark API key below, and change the first user's email to your own, or nobody else will be able to log in." ]
        , section ("Signups (" ++ String.fromInt (SeqDict.size model.submissions) ++ ")") [ submissionsView zone model ]
        , section "Users"
            [ Html.p [ Attr.style "margin-top" "0", Attr.style "color" Style.textMuted ]
                [ Html.text "Only these people can log in. Click a cell to edit it." ]
            , UserTable.view zone model.users model.userTable |> Html.map UserTableMsg
            , Html.div
                [ Attr.style "display" "flex"
                , Attr.style "flex-wrap" "wrap"
                , Attr.style "align-items" "center"
                , Attr.style "gap" "12px"
                , Attr.style "margin-top" "16px"
                ]
                (Style.smallButton (UserTableMsg UserTable.PressedAddUserRow) "Add user"
                    :: (if UserTable.hasChanges model.userTable then
                            [ Style.smallButton (UserTableMsg UserTable.PressedResetUserChanges) "Reset"
                            , Style.button PressedSaveUserChanges "Save changes"
                            ]

                        else
                            []
                       )
                    ++ [ case model.userTableError of
                            Just error ->
                                Html.span [ Attr.style "color" Style.error ] [ Html.text (UserTable.errorText error) ]

                            Nothing ->
                                Html.text ""
                       ]
                )
            ]
        , section "Login emails"
            [ Html.p [ Attr.style "margin-top" "0", Attr.style "color" Style.textMuted ]
                [ Html.text
                    (if model.postmarkKeySet then
                        "A Postmark API key is set, so login codes are sent by email. Saving an empty key turns login emails off and the recovery password back on."

                     else
                        "No Postmark API key is set yet."
                    )
                ]
            , Html.form
                [ Html.Events.onSubmit PressedSavePostmarkKey
                , Attr.style "display" "flex"
                , Attr.style "flex-wrap" "wrap"
                , Attr.style "gap" "12px"
                ]
                [ Html.input
                    [ Attr.type_ "password"
                    , Attr.value model.postmarkKeyInput
                    , Attr.placeholder "Postmark server API token"
                    , Attr.attribute "aria-label" "Postmark server API token"
                    , Html.Events.onInput TypedPostmarkKey
                    , Attr.style "flex" "1 1 280px"
                    , Attr.style "padding" "8px 10px"
                    , Attr.style "font" "inherit"
                    , Attr.style "border" ("1px solid " ++ Style.borderStrong)
                    , Attr.style "border-radius" "8px"
                    ]
                    []
                , Html.button
                    [ Attr.type_ "submit"
                    , Attr.style "padding" "8px 16px"
                    , Attr.style "border" "none"
                    , Attr.style "border-radius" "8px"
                    , Attr.style "background" Style.accent
                    , Attr.style "color" Style.background
                    , Attr.style "font" "inherit"
                    , Attr.style "font-weight" "600"
                    , Attr.style "cursor" "pointer"
                    ]
                    [ Html.text "Save key" ]
                ]
            ]
        ]


section : String -> List (Html msg) -> Html msg
section title content =
    Html.section [ Attr.style "margin-top" "40px" ]
        (Html.h2
            [ Attr.style "font-size" "18px"
            , Attr.style "letter-spacing" "0.08em"
            , Attr.style "text-transform" "uppercase"
            , Attr.style "color" Style.accent
            , Attr.style "padding-bottom" "8px"
            , Attr.style "border-bottom" ("1px solid " ++ Style.border)
            ]
            [ Html.text title ]
            :: content
        )


submissionsView : Time.Zone -> LoggedInModel -> Html FrontendMsg
submissionsView zone model =
    if SeqDict.isEmpty model.submissions then
        Html.p [ Attr.style "color" Style.textFaint ] [ Html.text "No signups yet." ]

    else
        Html.div [ Attr.style "overflow-x" "auto" ]
            [ Html.table
                [ Attr.style "border-collapse" "collapse", Attr.style "width" "100%", Attr.style "font-size" "15px" ]
                [ Html.thead []
                    [ Html.tr []
                        (List.map
                            (\title ->
                                Html.th
                                    [ Attr.style "text-align" "left"
                                    , Attr.style "padding" "8px"
                                    , Attr.style "border-bottom" ("1px solid " ++ Style.borderStrong)
                                    , Attr.style "white-space" "nowrap"
                                    ]
                                    [ Html.text title ]
                            )
                            [ "Submitted", "Name", "Email", "City", "Taking part as" ]
                        )
                    ]
                , Html.tbody []
                    (SeqDict.toList model.submissions
                        |> List.sortBy (\( _, submission ) -> -(Time.posixToMillis submission.submittedAt))
                        |> List.concatMap (submissionRows zone model)
                    )
                ]
            ]


submissionRows : Time.Zone -> LoggedInModel -> ( Id SubmissionId, Submission ) -> List (Html FrontendMsg)
submissionRows zone model ( submissionId, submission ) =
    let
        isExpanded : Bool
        isExpanded =
            model.expandedSubmission == Just submissionId

        cell : String -> Html msg
        cell text =
            Html.td [ Attr.style "padding" "8px" ] [ Html.text text ]
    in
    Html.tr
        [ Html.Events.onClick (PressedSubmission submissionId)
        , Attr.style "cursor" "pointer"
        , Attr.style "border-bottom" ("1px solid " ++ Style.border)
        , Attr.style "background"
            (if isExpanded then
                Style.surface

             else
                "transparent"
            )
        ]
        [ cell (Style.dateTime zone submission.submittedAt)
        , cell (Submission.field "first_name" submission ++ " " ++ Submission.field "last_name" submission)
        , cell (Submission.field "email" submission)
        , cell (Submission.field "city" submission)
        , cell (Submission.field "involvement" submission)
        ]
        :: (if isExpanded then
                [ Html.tr [ Attr.style "background" Style.surface ]
                    [ Html.td [ Attr.colspan 5, Attr.style "padding" "8px 8px 20px" ]
                        [ Html.dl
                            [ Attr.style "display" "grid"
                            , Attr.style "grid-template-columns" "minmax(140px, 240px) 1fr"
                            , Attr.style "gap" "8px 16px"
                            , Attr.style "margin" "0"
                            ]
                            (List.concatMap
                                (\( name, answer ) ->
                                    [ Html.dt [ Attr.style "color" Style.textFaint ] [ Html.text (Submission.questionLabel name) ]
                                    , Html.dd [ Attr.style "margin" "0", Attr.style "white-space" "pre-wrap" ] [ Html.text (Submission.answerText name answer) ]
                                    ]
                                )
                                submission.answers
                            )
                        , Html.div [ Attr.style "margin-top" "16px", Attr.style "display" "flex", Attr.style "gap" "12px", Attr.style "align-items" "center" ]
                            (if model.confirmDeleteSubmission == Just submissionId then
                                [ Html.span [] [ Html.text "Delete this signup for good?" ]
                                , Style.button (PressedConfirmDeleteSubmission submissionId) "Delete"
                                , Style.smallButton PressedCancelDeleteSubmission "Cancel"
                                ]

                             else
                                [ Style.smallButton (PressedDeleteSubmission submissionId) "Delete signup" ]
                            )
                        ]
                    ]
                ]

            else
                []
           )
