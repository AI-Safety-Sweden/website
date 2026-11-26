module Evergreen.V7.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Evergreen.V7.EmailAddress
import Evergreen.V7.Id
import Evergreen.V7.LoginForm
import Evergreen.V7.Postmark
import Evergreen.V7.SecretId
import Evergreen.V7.Submission
import Evergreen.V7.User
import Evergreen.V7.UserTable
import SeqDict
import Time
import Url


type alias LoggedInModel =
    { userId : Evergreen.V7.Id.Id Evergreen.V7.Id.UserId
    , users : SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId) Evergreen.V7.User.User
    , submissions : SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId) Evergreen.V7.Submission.Submission
    , userTable : Evergreen.V7.UserTable.UserTable
    , userTableError : Maybe Evergreen.V7.UserTable.UsersChangeError
    , notifyOnSignup : Bool
    , expandedSubmission : Maybe (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId)
    , confirmDeleteSubmission : Maybe (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId)
    , hoveredChartDay : Maybe String
    }


type Page
    = CheckingLogin
    | NotLoggedIn Evergreen.V7.LoginForm.LoginForm
    | LoggedIn LoggedInModel


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , zone : Time.Zone
    , time : Time.Posix
    , page : Page
    }


type alias PendingLogin =
    { creationTime : Time.Posix
    , userId : Evergreen.V7.Id.Id Evergreen.V7.Id.UserId
    , loginAttempts : Int
    , loginCode : Int
    }


type alias SignupNotifications =
    { lastSentAt : Maybe Time.Posix
    , pending : List (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId)
    }


type alias BackendModel =
    { users : SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId) Evergreen.V7.User.User
    , recentLoginEmails : SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId) (List Time.Posix)
    , sessions : SeqDict.SeqDict Effect.Lamdera.SessionId (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId)
    , pendingLogins : SeqDict.SeqDict Effect.Lamdera.SessionId PendingLogin
    , submissions : SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId) Evergreen.V7.Submission.Submission
    , signupNotifications : SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId) SignupNotifications
    , secretCounter : Int
    , serverSecret : Evergreen.V7.SecretId.SecretId Evergreen.V7.SecretId.ServerSecret
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url.Url
    | GotZone Time.Zone
    | GotTime Time.Posix
    | LoginFormMsg Evergreen.V7.LoginForm.Msg
    | PressedLogOut
    | UserTableMsg Evergreen.V7.UserTable.Msg
    | PressedSaveUserChanges
    | PressedExportSignups
    | ToggledNotifyOnSignup Bool
    | PressedSubmission (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId)
    | PressedDeleteSubmission (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId)
    | PressedConfirmDeleteSubmission (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId)
    | PressedCancelDeleteSubmission
    | HoveredChartDay String
    | UnhoveredChart


type ToBackend
    = CheckLoginRequest
    | GetLoginCodeRequest Evergreen.V7.EmailAddress.EmailAddress
    | LoginWithCodeRequest Int
    | LogOutRequest
    | ChangeUsersRequest Evergreen.V7.UserTable.UserChanges
    | DeleteSubmissionRequest (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId)
    | SetNotifyOnSignupRequest Bool


type BackendMsg
    = GotTimeForUpdateFromFrontend Effect.Lamdera.SessionId Effect.Lamdera.ClientId ToBackend Time.Posix
    | SentLoginEmail (Result Evergreen.V7.Postmark.SendEmailError ())
    | SubmissionReceived (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId)
    | GotTimeForSubmission (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId) Time.Posix
    | CheckSignupNotifications Time.Posix
    | SentSignupNotification (Result Evergreen.V7.Postmark.SendEmailError ())
    | SentSignupConfirmation (Result Evergreen.V7.Postmark.SendEmailError ())


type alias AdminData =
    { userId : Evergreen.V7.Id.Id Evergreen.V7.Id.UserId
    , users : SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId) Evergreen.V7.User.User
    , submissions : SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId) Evergreen.V7.Submission.Submission
    , notifyOnSignup : Bool
    }


type ToFrontend
    = CheckLoginResponse (Result () AdminData)
    | GetLoginCodeRateLimited
    | EmailNotAllowedResponse
    | LoginWithCodeResponse (Result Int AdminData)
    | LoggedOutResponse
    | UsersChanged (SeqDict.SeqDict (Evergreen.V7.Id.Id Evergreen.V7.Id.UserId) Evergreen.V7.User.User)
    | ChangeUsersRejected Evergreen.V7.UserTable.UsersChangeError
    | SubmissionAdded (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId) Evergreen.V7.Submission.Submission
    | SubmissionDeleted (Evergreen.V7.Id.Id Evergreen.V7.Id.SubmissionId)
    | NotifyOnSignupChanged Bool
