module Types exposing
    ( AdminData
    , BackendModel
    , BackendMsg(..)
    , FrontendModel
    , FrontendMsg(..)
    , LoggedInModel
    , LoginType(..)
    , Page(..)
    , PendingLogin
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
    | NotLoggedIn LoginType LoginForm
    | LoggedIn LoggedInModel


type alias LoggedInModel =
    { userId : Id UserId
    , users : SeqDict (Id UserId) User
    , submissions : SeqDict (Id SubmissionId) Submission
    , postmarkKeySet : Bool
    , userTable : UserTable
    , userTableError : Maybe UsersChangeError
    , expandedSubmission : Maybe (Id SubmissionId)
    , confirmDeleteSubmission : Maybe (Id SubmissionId)
    , postmarkKeyInput : String
    }


{-| Logging in normally means typing in a code sent by email. Until a Postmark API key has been
set, no emails can be sent, so the first user logs in with the recovery password instead.
-}
type LoginType
    = LoginWithEmail
    | LoginWithRecoveryPassword


type alias AdminData =
    { userId : Id UserId
    , users : SeqDict (Id UserId) User
    , submissions : SeqDict (Id SubmissionId) Submission
    , postmarkKeySet : Bool
    }


type alias BackendModel =
    { users : SeqDict (Id UserId) User
    , recentLoginEmails : SeqDict (Id UserId) (List Time.Posix)
    , sessions : SeqDict SessionId (Id UserId)
    , pendingLogins : SeqDict SessionId PendingLogin
    , submissions : SeqDict (Id SubmissionId) Submission
    , postmarkApiKey : Postmark.ApiKey
    , secretCounter : Int
    , serverSecret : SecretId ServerSecret
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
    | PressedSubmission (Id SubmissionId)
    | PressedDeleteSubmission (Id SubmissionId)
    | PressedConfirmDeleteSubmission (Id SubmissionId)
    | PressedCancelDeleteSubmission
    | TypedPostmarkKey String
    | PressedSavePostmarkKey


type ToBackend
    = CheckLoginRequest
    | GetLoginCodeRequest EmailAddress
    | LoginWithCodeRequest Int
    | LoginWithRecoveryPasswordRequest String
    | LogOutRequest
    | ChangeUsersRequest UserChanges
    | DeleteSubmissionRequest (Id SubmissionId)
    | SetPostmarkKeyRequest Postmark.ApiKey


type BackendMsg
    = GotTimeForUpdateFromFrontend SessionId ClientId ToBackend Time.Posix
    | SentLoginEmail (Result Postmark.SendEmailError ())
    | SubmissionReceived (Id SubmissionId)


type ToFrontend
    = CheckLoginResponse (Result LoginType AdminData)
    | GetLoginCodeRateLimited
    | EmailNotAllowedResponse
    | LoginWithCodeResponse (Result Int AdminData)
    | RecoveryPasswordInvalidResponse
    | LoggedOutResponse
    | UsersChanged (SeqDict (Id UserId) User)
    | ChangeUsersRejected UsersChangeError
    | SubmissionAdded (Id SubmissionId) Submission
    | SubmissionDeleted (Id SubmissionId)
    | PostmarkKeyChanged Bool
