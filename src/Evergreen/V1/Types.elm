module Evergreen.V1.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Evergreen.V1.EmailAddress
import Evergreen.V1.Id
import Evergreen.V1.LoginForm
import Evergreen.V1.Postmark
import Evergreen.V1.SecretId
import Evergreen.V1.Submission
import Evergreen.V1.User
import Evergreen.V1.UserTable
import SeqDict
import Time
import Url


type alias LoggedInModel =
    { userId : Evergreen.V1.Id.Id Evergreen.V1.Id.UserId
    , users : SeqDict.SeqDict (Evergreen.V1.Id.Id Evergreen.V1.Id.UserId) Evergreen.V1.User.User
    , submissions : SeqDict.SeqDict (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId) Evergreen.V1.Submission.Submission
    , userTable : Evergreen.V1.UserTable.UserTable
    , userTableError : Maybe Evergreen.V1.UserTable.UsersChangeError
    , notifyOnSignup : Bool
    , expandedSubmission : Maybe (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId)
    , confirmDeleteSubmission : Maybe (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId)
    }


type Page
    = CheckingLogin
    | NotLoggedIn Evergreen.V1.LoginForm.LoginForm
    | LoggedIn LoggedInModel


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , zone : Time.Zone
    , time : Time.Posix
    , page : Page
    }


type alias PendingLogin =
    { creationTime : Time.Posix
    , userId : Evergreen.V1.Id.Id Evergreen.V1.Id.UserId
    , loginAttempts : Int
    , loginCode : Int
    }


type alias SignupNotifications =
    { lastSentAt : Maybe Time.Posix
    , pending : List (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId)
    }


type alias BackendModel =
    { users : SeqDict.SeqDict (Evergreen.V1.Id.Id Evergreen.V1.Id.UserId) Evergreen.V1.User.User
    , recentLoginEmails : SeqDict.SeqDict (Evergreen.V1.Id.Id Evergreen.V1.Id.UserId) (List Time.Posix)
    , sessions : SeqDict.SeqDict Effect.Lamdera.SessionId (Evergreen.V1.Id.Id Evergreen.V1.Id.UserId)
    , pendingLogins : SeqDict.SeqDict Effect.Lamdera.SessionId PendingLogin
    , submissions : SeqDict.SeqDict (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId) Evergreen.V1.Submission.Submission
    , signupNotifications : SeqDict.SeqDict (Evergreen.V1.Id.Id Evergreen.V1.Id.UserId) SignupNotifications
    , secretCounter : Int
    , serverSecret : Evergreen.V1.SecretId.SecretId Evergreen.V1.SecretId.ServerSecret
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url.Url
    | GotZone Time.Zone
    | GotTime Time.Posix
    | LoginFormMsg Evergreen.V1.LoginForm.Msg
    | PressedLogOut
    | UserTableMsg Evergreen.V1.UserTable.Msg
    | PressedSaveUserChanges
    | PressedExportSignups
    | ToggledNotifyOnSignup Bool
    | PressedSubmission (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId)
    | PressedDeleteSubmission (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId)
    | PressedConfirmDeleteSubmission (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId)
    | PressedCancelDeleteSubmission


type ToBackend
    = CheckLoginRequest
    | GetLoginCodeRequest Evergreen.V1.EmailAddress.EmailAddress
    | LoginWithCodeRequest Int
    | LogOutRequest
    | ChangeUsersRequest Evergreen.V1.UserTable.UserChanges
    | DeleteSubmissionRequest (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId)
    | SetNotifyOnSignupRequest Bool


type BackendMsg
    = GotTimeForUpdateFromFrontend Effect.Lamdera.SessionId Effect.Lamdera.ClientId ToBackend Time.Posix
    | SentLoginEmail (Result Evergreen.V1.Postmark.SendEmailError ())
    | SubmissionReceived (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId)
    | GotTimeForSubmission (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId) Time.Posix
    | CheckSignupNotifications Time.Posix
    | SentSignupNotification (Result Evergreen.V1.Postmark.SendEmailError ())
    | SentSignupConfirmation (Result Evergreen.V1.Postmark.SendEmailError ())


type alias AdminData =
    { userId : Evergreen.V1.Id.Id Evergreen.V1.Id.UserId
    , users : SeqDict.SeqDict (Evergreen.V1.Id.Id Evergreen.V1.Id.UserId) Evergreen.V1.User.User
    , submissions : SeqDict.SeqDict (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId) Evergreen.V1.Submission.Submission
    , notifyOnSignup : Bool
    }


type ToFrontend
    = CheckLoginResponse (Result () AdminData)
    | GetLoginCodeRateLimited
    | EmailNotAllowedResponse
    | LoginWithCodeResponse (Result Int AdminData)
    | LoggedOutResponse
    | UsersChanged (SeqDict.SeqDict (Evergreen.V1.Id.Id Evergreen.V1.Id.UserId) Evergreen.V1.User.User)
    | ChangeUsersRejected Evergreen.V1.UserTable.UsersChangeError
    | SubmissionAdded (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId) Evergreen.V1.Submission.Submission
    | SubmissionDeleted (Evergreen.V1.Id.Id Evergreen.V1.Id.SubmissionId)
    | NotifyOnSignupChanged Bool
