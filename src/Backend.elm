module Backend exposing (app, app_)

import Duration
import Effect.Command as Command exposing (BackendOnly, Command)
import Effect.Lamdera as Lamdera exposing (ClientId, SessionId)
import Effect.Subscription as Subscription exposing (Subscription)
import Effect.Task as Task
import Effect.Time as Time
import Email.Html
import Email.Html.Attributes
import EmailAddress exposing (EmailAddress)
import Env
import Hex
import Id exposing (Id, SubmissionId, UserId)
import Lamdera as LamderaCore
import List.Nonempty
import LoginForm
import Postmark
import Quantity
import SecretId
import SeqDict exposing (SeqDict)
import String.Nonempty exposing (NonemptyString(..))
import Submission
import Types exposing (AdminData, BackendModel, BackendMsg(..), SignupNotifications, ToBackend(..), ToFrontend(..))
import User exposing (User)
import UserTable


app :
    { init : ( BackendModel, Cmd BackendMsg )
    , update : BackendMsg -> BackendModel -> ( BackendModel, Cmd BackendMsg )
    , updateFromFrontend : String -> String -> ToBackend -> BackendModel -> ( BackendModel, Cmd BackendMsg )
    , subscriptions : BackendModel -> Sub BackendMsg
    }
app =
    Lamdera.backend LamderaCore.broadcast LamderaCore.sendToFrontend app_


app_ :
    { init : ( BackendModel, Command BackendOnly ToFrontend BackendMsg )
    , update : BackendMsg -> BackendModel -> ( BackendModel, Command BackendOnly ToFrontend BackendMsg )
    , updateFromFrontend : SessionId -> ClientId -> ToBackend -> BackendModel -> ( BackendModel, Command BackendOnly ToFrontend BackendMsg )
    , subscriptions : BackendModel -> Subscription BackendOnly BackendMsg
    }
app_ =
    { init = init
    , update = update
    , updateFromFrontend = updateFromFrontend
    , subscriptions = subscriptions
    }


subscriptions : BackendModel -> Subscription BackendOnly BackendMsg
subscriptions model =
    if List.any (\notifications -> not (List.isEmpty notifications.pending)) (SeqDict.values model.signupNotifications) then
        Time.every Duration.minute CheckSignupNotifications

    else
        Subscription.none


{-| `Env.adminEmail` can always log in. If they aren't in the user table (it's empty when the app
first starts, or someone deleted them), they get added back when they ask for a login code.
-}
withAdminUser : Time.Posix -> SeqDict (Id UserId) User -> SeqDict (Id UserId) User
withAdminUser time users =
    case EmailAddress.fromString Env.adminEmail of
        Just email ->
            case findUserByEmail email users of
                Just _ ->
                    users

                Nothing ->
                    SeqDict.insert
                        (SeqDict.keys users |> List.map Id.toInt |> List.maximum |> Maybe.withDefault -1 |> (+) 1 |> Id.fromInt)
                        { name = "Admin", email = email, createdAt = time }
                        users

        Nothing ->
            users


init : ( BackendModel, Command BackendOnly ToFrontend BackendMsg )
init =
    ( { users = SeqDict.empty
      , recentLoginEmails = SeqDict.empty
      , sessions = SeqDict.empty
      , pendingLogins = SeqDict.empty
      , submissions = SeqDict.empty
      , signupNotifications = SeqDict.empty
      , secretCounter = 0
      , serverSecret = SecretId.fromString Env.secretKey
      }
    , Command.none
    )


update : BackendMsg -> BackendModel -> ( BackendModel, Command BackendOnly ToFrontend BackendMsg )
update msg model =
    case msg of
        GotTimeForUpdateFromFrontend sessionId clientId toBackend time ->
            updateFromFrontendWithTime time sessionId clientId toBackend model

        SentLoginEmail _ ->
            ( model, Command.none )

        SubmissionReceived submissionId ->
            case SeqDict.get submissionId model.submissions of
                Just submission ->
                    ( model
                    , Command.batch
                        [ toLoggedInSessions model (SubmissionAdded submissionId submission)
                        , Task.perform (GotTimeForSubmission submissionId) Time.now
                        ]
                    )

                Nothing ->
                    ( model, Command.none )

        GotTimeForSubmission submissionId time ->
            SeqDict.foldl
                (\userId notifications ( model2, cmds ) ->
                    if List.isEmpty notifications.pending && hourHasPassed time notifications then
                        ( { model2
                            | signupNotifications =
                                SeqDict.insert userId { lastSentAt = Just time, pending = [] } model2.signupNotifications
                          }
                        , sendSignupNotification userId [ submissionId ] model2 :: cmds
                        )

                    else
                        ( { model2
                            | signupNotifications =
                                SeqDict.insert
                                    userId
                                    { notifications | pending = notifications.pending ++ [ submissionId ] }
                                    model2.signupNotifications
                          }
                        , cmds
                        )
                )
                ( model, [] )
                model.signupNotifications
                |> Tuple.mapSecond Command.batch

        CheckSignupNotifications time ->
            SeqDict.foldl
                (\userId notifications ( model2, cmds ) ->
                    if not (List.isEmpty notifications.pending) && hourHasPassed time notifications then
                        ( { model2
                            | signupNotifications =
                                SeqDict.insert userId { lastSentAt = Just time, pending = [] } model2.signupNotifications
                          }
                        , sendSignupNotification userId notifications.pending model2 :: cmds
                        )

                    else
                        ( model2, cmds )
                )
                ( model, [] )
                model.signupNotifications
                |> Tuple.mapSecond Command.batch

        SentSignupNotification _ ->
            ( model, Command.none )


updateFromFrontend : SessionId -> ClientId -> ToBackend -> BackendModel -> ( BackendModel, Command BackendOnly ToFrontend BackendMsg )
updateFromFrontend sessionId clientId msg model =
    ( model, Task.perform (GotTimeForUpdateFromFrontend sessionId clientId msg) Time.now )


updateFromFrontendWithTime : Time.Posix -> SessionId -> ClientId -> ToBackend -> BackendModel -> ( BackendModel, Command BackendOnly ToFrontend BackendMsg )
updateFromFrontendWithTime time sessionId clientId msg model =
    case msg of
        CheckLoginRequest ->
            ( model
            , (case SeqDict.get sessionId model.sessions of
                Just userId ->
                    Ok (adminData userId model)

                Nothing ->
                    Err ()
              )
                |> CheckLoginResponse
                |> Lamdera.sendToFrontend clientId
            )

        GetLoginCodeRequest email ->
            let
                users : SeqDict (Id UserId) User
                users =
                    withAdminUser time model.users
            in
            case findUserByEmail email users of
                Just ( userId, _ ) ->
                    let
                        recentLogins : List Time.Posix
                        recentLogins =
                            SeqDict.get userId model.recentLoginEmails |> Maybe.withDefault []
                    in
                    if shouldRateLimit time recentLogins then
                        ( model, Lamdera.sendToFrontend clientId GetLoginCodeRateLimited )

                    else
                        let
                            ( model2, loginCode ) =
                                getLoginCode time { model | users = users }
                        in
                        ( { model2
                            | pendingLogins =
                                SeqDict.insert
                                    sessionId
                                    { creationTime = time, userId = userId, loginAttempts = 0, loginCode = loginCode }
                                    model2.pendingLogins
                            , recentLoginEmails =
                                SeqDict.insert userId (time :: List.take 20 recentLogins) model2.recentLoginEmails
                          }
                        , sendLoginEmail email loginCode
                        )

                Nothing ->
                    ( model, Lamdera.sendToFrontend clientId EmailNotAllowedResponse )

        LoginWithCodeRequest loginCode ->
            case SeqDict.get sessionId model.pendingLogins of
                Just pendingLogin ->
                    if
                        (pendingLogin.loginAttempts < LoginForm.maxLoginAttempts)
                            && (Duration.from pendingLogin.creationTime time |> Quantity.lessThan Duration.hour)
                            && SeqDict.member pendingLogin.userId model.users
                    then
                        if loginCode == pendingLogin.loginCode then
                            logIn sessionId pendingLogin.userId model

                        else
                            ( { model
                                | pendingLogins =
                                    SeqDict.insert
                                        sessionId
                                        { pendingLogin | loginAttempts = pendingLogin.loginAttempts + 1 }
                                        model.pendingLogins
                              }
                            , Lamdera.sendToFrontend clientId (LoginWithCodeResponse (Err loginCode))
                            )

                    else
                        ( model, Lamdera.sendToFrontend clientId (LoginWithCodeResponse (Err loginCode)) )

                Nothing ->
                    ( model, Lamdera.sendToFrontend clientId (LoginWithCodeResponse (Err loginCode)) )

        LogOutRequest ->
            ( { model | sessions = SeqDict.remove sessionId model.sessions }
            , Lamdera.sendToFrontends sessionId LoggedOutResponse
            )

        ChangeUsersRequest changes ->
            asUser
                sessionId
                model
                (\userId ->
                    case UserTable.applyChanges time userId changes model.users of
                        Ok users ->
                            let
                                removedSessions : List SessionId
                                removedSessions =
                                    SeqDict.toList model.sessions
                                        |> List.filter (\( _, sessionUserId ) -> not (SeqDict.member sessionUserId users))
                                        |> List.map Tuple.first

                                model2 : BackendModel
                                model2 =
                                    { model
                                        | users = users
                                        , sessions = SeqDict.filter (\_ sessionUserId -> SeqDict.member sessionUserId users) model.sessions
                                        , recentLoginEmails = SeqDict.filter (\id _ -> SeqDict.member id users) model.recentLoginEmails
                                        , signupNotifications = SeqDict.filter (\id _ -> SeqDict.member id users) model.signupNotifications
                                    }
                            in
                            ( model2
                            , Command.batch
                                [ toLoggedInSessions model2 (UsersChanged users)
                                , List.map (\removedSession -> Lamdera.sendToFrontends removedSession LoggedOutResponse) removedSessions
                                    |> Command.batch
                                ]
                            )

                        Err error ->
                            ( model, Lamdera.sendToFrontend clientId (ChangeUsersRejected error) )
                )

        DeleteSubmissionRequest submissionId ->
            asUser
                sessionId
                model
                (\_ ->
                    let
                        model2 : BackendModel
                        model2 =
                            { model | submissions = SeqDict.remove submissionId model.submissions }
                    in
                    ( model2, toLoggedInSessions model2 (SubmissionDeleted submissionId) )
                )

        SetNotifyOnSignupRequest enabled ->
            asUser
                sessionId
                model
                (\userId ->
                    ( { model
                        | signupNotifications =
                            if enabled then
                                SeqDict.update
                                    userId
                                    (\maybe -> Just (Maybe.withDefault { lastSentAt = Nothing, pending = [] } maybe))
                                    model.signupNotifications

                            else
                                SeqDict.remove userId model.signupNotifications
                      }
                    , SeqDict.toList model.sessions
                        |> List.filter (\( _, sessionUserId ) -> sessionUserId == userId)
                        |> List.map (\( userSession, _ ) -> Lamdera.sendToFrontends userSession (NotifyOnSignupChanged enabled))
                        |> Command.batch
                    )
                )


asUser :
    SessionId
    -> BackendModel
    -> (Id UserId -> ( BackendModel, Command BackendOnly ToFrontend BackendMsg ))
    -> ( BackendModel, Command BackendOnly ToFrontend BackendMsg )
asUser sessionId model func =
    case SeqDict.get sessionId model.sessions of
        Just userId ->
            func userId

        Nothing ->
            ( model, Command.none )


logIn : SessionId -> Id UserId -> BackendModel -> ( BackendModel, Command BackendOnly ToFrontend BackendMsg )
logIn sessionId userId model =
    let
        model2 : BackendModel
        model2 =
            { model
                | sessions = SeqDict.insert sessionId userId model.sessions
                , pendingLogins = SeqDict.remove sessionId model.pendingLogins
            }
    in
    ( model2
    , Lamdera.sendToFrontends sessionId (LoginWithCodeResponse (Ok (adminData userId model2)))
    )


adminData : Id UserId -> BackendModel -> AdminData
adminData userId model =
    { userId = userId
    , users = model.users
    , submissions = model.submissions
    , notifyOnSignup = SeqDict.member userId model.signupNotifications
    }


hourHasPassed : Time.Posix -> SignupNotifications -> Bool
hourHasPassed time notifications =
    case notifications.lastSentAt of
        Just lastSentAt ->
            Duration.from lastSentAt time |> Quantity.greaterThanOrEqualTo Duration.hour

        Nothing ->
            True


toLoggedInSessions : BackendModel -> ToFrontend -> Command BackendOnly ToFrontend BackendMsg
toLoggedInSessions model toFrontend =
    SeqDict.keys model.sessions
        |> List.map (\sessionId -> Lamdera.sendToFrontends sessionId toFrontend)
        |> Command.batch


findUserByEmail : EmailAddress -> SeqDict (Id UserId) User -> Maybe ( Id UserId, User )
findUserByEmail email users =
    SeqDict.toList users
        |> List.filter
            (\( _, user ) -> String.toLower (EmailAddress.toString user.email) == String.toLower (EmailAddress.toString email))
        |> List.head


shouldRateLimit : Time.Posix -> List Time.Posix -> Bool
shouldRateLimit time recentLogins =
    let
        loginsInLast : Float -> Int
        loginsInLast minutes =
            List.filter (\loginTime -> Duration.from loginTime time |> Quantity.lessThan (Duration.minutes minutes)) recentLogins
                |> List.length
    in
    loginsInLast 5 > 5 || loginsInLast 120 > 10


getLoginCode : Time.Posix -> BackendModel -> ( BackendModel, Int )
getLoginCode time model =
    let
        ( model2, id ) =
            SecretId.getUniqueId time model

        digits : String
        digits =
            case Hex.fromString (String.left 12 (SecretId.toString id)) of
                Ok int ->
                    String.fromInt int

                Err _ ->
                    ""
    in
    ( model2
    , String.right LoginForm.loginCodeLength digits |> String.toInt |> Maybe.withDefault 0
    )


noReplyEmailAddress : Maybe EmailAddress
noReplyEmailAddress =
    EmailAddress.fromString "no-reply@aisafetysweden.se"


sendLoginEmail : EmailAddress -> Int -> Command BackendOnly ToFrontend BackendMsg
sendLoginEmail emailAddress loginCode =
    let
        loginCode2 : String
        loginCode2 =
            String.padLeft LoginForm.loginCodeLength '0' (String.fromInt loginCode)
                |> (\code ->
                        if Env.isProduction then
                            code

                        else
                            Debug.log "login code" code
                   )
    in
    case noReplyEmailAddress of
        Just from ->
            { from = { name = "AI Safety Sweden", email = from }
            , to = List.Nonempty.fromElement { name = "", email = emailAddress }
            , subject = NonemptyString 'Y' "our AI Safety Sweden admin login code"
            , body =
                Postmark.BodyBoth
                    (Email.Html.div
                        [ Email.Html.Attributes.padding "8px" ]
                        [ Email.Html.div [] [ Email.Html.text "Here is your login code." ]
                        , Email.Html.div
                            [ Email.Html.Attributes.fontSize "36px"
                            , Email.Html.Attributes.fontFamily "monospace"
                            , Email.Html.Attributes.style "letter-spacing" "4px"
                            ]
                            [ Email.Html.text loginCode2 ]
                        , Email.Html.div [] [ Email.Html.text "If you weren't expecting this email you can safely ignore it." ]
                        ]
                    )
                    ("Here is your login code " ++ loginCode2 ++ "\n\nIf you weren't expecting this email you can safely ignore it.")
            , messageStream = "outbound"
            }
                |> Postmark.sendEmail SentLoginEmail (Postmark.apiKey Env.postmarkApiKey)

        Nothing ->
            Command.none


adminSiteUrl : String
adminSiteUrl =
    "https://ai-safety-sweden.lamdera.app"


sendSignupNotification : Id UserId -> List (Id SubmissionId) -> BackendModel -> Command BackendOnly ToFrontend BackendMsg
sendSignupNotification userId submissionIds model =
    let
        people : List String
        people =
            List.filterMap
                (\submissionId ->
                    SeqDict.get submissionId model.submissions
                        |> Maybe.map
                            (\submission ->
                                Submission.field "first_name" submission
                                    ++ " "
                                    ++ Submission.field "last_name" submission
                                    ++ " ("
                                    ++ Submission.field "email" submission
                                    ++ ")"
                            )
                )
                submissionIds
    in
    case
        ( SeqDict.get userId model.users
        , noReplyEmailAddress
        , if Env.isProduction then
            people

          else
            Debug.log "signup notification" people
        )
    of
        ( Just user, Just from, [ person ] ) ->
            signupEmail from user.email (NonemptyString 'N' ("ew signup: " ++ person)) [ person ]

        ( Just user, Just from, _ :: _ :: _ ) ->
            signupEmail from user.email (NonemptyString 'N' ("ew signups: " ++ String.fromInt (List.length people))) people

        _ ->
            Command.none


signupEmail : EmailAddress -> EmailAddress -> NonemptyString -> List String -> Command BackendOnly ToFrontend BackendMsg
signupEmail from to subject people =
    { from = { name = "AI Safety Sweden", email = from }
    , to = List.Nonempty.fromElement { name = "", email = to }
    , subject = subject
    , body =
        Postmark.BodyBoth
            (Email.Html.div
                [ Email.Html.Attributes.padding "8px" ]
                [ Email.Html.div [] [ Email.Html.text "New signups on aisafetysweden.se:" ]
                , Email.Html.ul [] (List.map (\person -> Email.Html.li [] [ Email.Html.text person ]) people)
                , Email.Html.div [] [ Email.Html.text ("See them at " ++ adminSiteUrl) ]
                , Email.Html.div [ Email.Html.Attributes.color "#626B66" ]
                    [ Email.Html.text "You get these because email notifications are turned on in the admin site. After an email, further signups wait an hour and come together." ]
                ]
            )
            ("New signups on aisafetysweden.se:\n\n"
                ++ String.join "\n" (List.map (\person -> "- " ++ person) people)
                ++ "\n\nSee them at "
                ++ adminSiteUrl
                ++ "\n\nYou get these because email notifications are turned on in the admin site. After an email, further signups wait an hour and come together."
            )
    , messageStream = "outbound"
    }
        |> Postmark.sendEmail SentSignupNotification (Postmark.apiKey Env.postmarkApiKey)
