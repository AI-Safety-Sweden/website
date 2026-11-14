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
import Id exposing (Id, UserId)
import Lamdera as LamderaCore
import List.Nonempty
import LoginForm
import Postmark
import Quantity
import SecretId
import SeqDict exposing (SeqDict)
import Sha256
import String.Nonempty exposing (NonemptyString(..))
import Types exposing (AdminData, BackendModel, BackendMsg(..), LoginType(..), ToBackend(..), ToFrontend(..))
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
    , subscriptions = \_ -> Subscription.none
    }


{-| The first user. Log in as them with the recovery password, then change the email to your own
in the user table.
-}
initialUsers : SeqDict (Id UserId) User
initialUsers =
    case EmailAddress.fromString "a@a.aa" of
        Just email ->
            SeqDict.singleton (Id.fromInt 0) { name = "Admin", email = email, createdAt = Time.millisToPosix 0 }

        Nothing ->
            SeqDict.empty


{-| Sha256 hash of the password that logs you in as the first user while there's no Postmark API
key (so no login emails can be sent). It's the same as at-chat's.
-}
recoveryPasswordHash : String
recoveryPasswordHash =
    "0e6a28a18a696783861f4eda27b09caa96718799deb31d701321cb3a9530d913"


loginType : BackendModel -> LoginType
loginType model =
    if model.postmarkApiKey == Postmark.apiKey "" then
        LoginWithRecoveryPassword

    else
        LoginWithEmail


init : ( BackendModel, Command BackendOnly ToFrontend BackendMsg )
init =
    ( { users = initialUsers
      , recentLoginEmails = SeqDict.empty
      , sessions = SeqDict.empty
      , pendingLogins = SeqDict.empty
      , submissions = SeqDict.empty
      , postmarkApiKey = Postmark.apiKey ""
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
                    ( model, toLoggedInSessions model (SubmissionAdded submissionId submission) )

                Nothing ->
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
                    Err (loginType model)
              )
                |> CheckLoginResponse
                |> Lamdera.sendToFrontend clientId
            )

        GetLoginCodeRequest email ->
            case findUserByEmail email model.users of
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
                                getLoginCode time model
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
                        , sendLoginEmail email loginCode model2.postmarkApiKey
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

        LoginWithRecoveryPasswordRequest password ->
            case ( loginType model, SeqDict.keys model.users |> List.head ) of
                ( LoginWithRecoveryPassword, Just userId ) ->
                    if Sha256.sha256 password == recoveryPasswordHash then
                        logIn sessionId userId model

                    else
                        ( model, Lamdera.sendToFrontend clientId RecoveryPasswordInvalidResponse )

                _ ->
                    ( model, Lamdera.sendToFrontend clientId RecoveryPasswordInvalidResponse )

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

        SetPostmarkKeyRequest apiKey ->
            asUser
                sessionId
                model
                (\_ ->
                    let
                        model2 : BackendModel
                        model2 =
                            { model | postmarkApiKey = apiKey }
                    in
                    ( model2, toLoggedInSessions model2 (PostmarkKeyChanged (loginType model2 == LoginWithEmail)) )
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
    , postmarkKeySet = loginType model == LoginWithEmail
    }


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


sendLoginEmail : EmailAddress -> Int -> Postmark.ApiKey -> Command BackendOnly ToFrontend BackendMsg
sendLoginEmail emailAddress loginCode apiKey =
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
                |> Postmark.sendEmail SentLoginEmail apiKey

        Nothing ->
            Command.none
