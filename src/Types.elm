module Types exposing
    ( AdminData
    , BackendModel
    , BackendMsg(..)
    , FrontendModel
    , FrontendMsg(..)
    , LoggedInModel
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
    | NotLoggedIn LoginForm
    | LoggedIn LoggedInModel


type alias LoggedInModel =
    { userId : Id UserId
    , users : SeqDict (Id UserId) User
    , submissions : SeqDict (Id SubmissionId) Submission
    , userTable : UserTable
    , userTableError : Maybe UsersChangeError
    , expandedSubmission : Maybe (Id SubmissionId)
    , confirmDeleteSubmission : Maybe (Id SubmissionId)
    }


type alias AdminData =
    { userId : Id UserId
    , users : SeqDict (Id UserId) User
    , submissions : SeqDict (Id SubmissionId) Submission
    }


type alias BackendModel =
    { users : SeqDict (Id UserId) User
    , recentLoginEmails : SeqDict (Id UserId) (List Time.Posix)
    , sessions : SeqDict SessionId (Id UserId)
    , pendingLogins : SeqDict SessionId PendingLogin
    , submissions : SeqDict (Id SubmissionId) Submission
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
    | PressedExportSignups
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


type BackendMsg
    = GotTimeForUpdateFromFrontend SessionId ClientId ToBackend Time.Posix
    | SentLoginEmail (Result Postmark.SendEmailError ())
    | SubmissionReceived (Id SubmissionId)


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
