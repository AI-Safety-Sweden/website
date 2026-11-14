module Types exposing
    ( AdminData
    , BackendModel
    , BackendMsg(..)
    , FrontendModel
    , FrontendMsg(..)
    , LoggedInModel
    , Page(..)
    , PendingLogin
    , SignupNotifications
    , ToBackend(..)
    , ToFrontend(..)
    )

import Effect.Browser exposing (UrlRequest)
import Effect.Browser.Navigation exposing (Key)
import Effect.Lamdera exposing (ClientId, SessionId)
import EmailAddress exposing (EmailAddress)
import Id exposing (Id, SubmissionId, UserId)
import LoginForm exposing (LoginForm)
import Postmark
import SecretId exposing (SecretId, ServerSecret)
import SeqDict exposing (SeqDict)
import Submission exposing (Submission)
import Time
import Url exposing (Url)
import User exposing (User)
import UserTable exposing (UserChanges, UserTable, UsersChangeError)


type alias FrontendModel =
    { key : Key
    , zone : Time.Zone
    , time : Time.Posix
    , page : Page
    }


type Page
    = CheckingLogin
    | NotLoggedIn LoginForm
    | LoggedIn LoggedInModel


type alias LoggedInModel =
    { userId : Id UserId
    , users : SeqDict (Id UserId) User
    , submissions : SeqDict (Id SubmissionId) Submission
    , userTable : UserTable
    , userTableError : Maybe UsersChangeError
    , notifyOnSignup : Bool
    , expandedSubmission : Maybe (Id SubmissionId)
    , confirmDeleteSubmission : Maybe (Id SubmissionId)
    }


type alias AdminData =
    { userId : Id UserId
    , users : SeqDict (Id UserId) User
    , submissions : SeqDict (Id SubmissionId) Submission
    , notifyOnSignup : Bool
    }


type alias BackendModel =
    { users : SeqDict (Id UserId) User
    , recentLoginEmails : SeqDict (Id UserId) (List Time.Posix)
    , sessions : SeqDict SessionId (Id UserId)
    , pendingLogins : SeqDict SessionId PendingLogin
    , submissions : SeqDict (Id SubmissionId) Submission
    , signupNotifications : SeqDict (Id UserId) SignupNotifications
    , secretCounter : Int
    , serverSecret : SecretId ServerSecret
    }


{-| Users in this dict get emailed about new signups. The first signup is emailed straight away,
then any others wait until an hour after the last email, and are sent together.
-}
type alias SignupNotifications =
    { lastSentAt : Maybe Time.Posix
    , pending : List (Id SubmissionId)
    }


type alias PendingLogin =
    { creationTime : Time.Posix
    , userId : Id UserId
    , loginAttempts : Int
    , loginCode : Int
    }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
    | GotZone Time.Zone
    | GotTime Time.Posix
    | LoginFormMsg LoginForm.Msg
    | PressedLogOut
    | UserTableMsg UserTable.Msg
    | PressedSaveUserChanges
    | PressedExportSignups
    | ToggledNotifyOnSignup Bool
    | PressedSubmission (Id SubmissionId)
    | PressedDeleteSubmission (Id SubmissionId)
    | PressedConfirmDeleteSubmission (Id SubmissionId)
    | PressedCancelDeleteSubmission


type ToBackend
    = CheckLoginRequest
    | GetLoginCodeRequest EmailAddress
    | LoginWithCodeRequest Int
    | LogOutRequest
    | ChangeUsersRequest UserChanges
    | DeleteSubmissionRequest (Id SubmissionId)
    | SetNotifyOnSignupRequest Bool


type BackendMsg
    = GotTimeForUpdateFromFrontend SessionId ClientId ToBackend Time.Posix
    | SentLoginEmail (Result Postmark.SendEmailError ())
    | SubmissionReceived (Id SubmissionId)
    | GotTimeForSubmission (Id SubmissionId) Time.Posix
    | CheckSignupNotifications Time.Posix
    | SentSignupNotification (Result Postmark.SendEmailError ())
    | SentSignupConfirmation (Result Postmark.SendEmailError ())


type ToFrontend
    = CheckLoginResponse (Result () AdminData)
    | GetLoginCodeRateLimited
    | EmailNotAllowedResponse
    | LoginWithCodeResponse (Result Int AdminData)
    | LoggedOutResponse
    | UsersChanged (SeqDict (Id UserId) User)
    | ChangeUsersRejected UsersChangeError
    | SubmissionAdded (Id SubmissionId) Submission
    | SubmissionDeleted (Id SubmissionId)
    | NotifyOnSignupChanged Bool
