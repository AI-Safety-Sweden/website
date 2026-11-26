module Evergreen.V7.LoginForm exposing (..)

import Evergreen.V7.EmailAddress


type EmailProblem
    = RateLimited
    | NotAllowed


type alias EnterEmail2 =
    { email : String
    , pressedSubmit : Bool
    , problem : Maybe EmailProblem
    }


type alias EnterLoginCode2 =
    { sentTo : Evergreen.V7.EmailAddress.EmailAddress
    , code : String
    , checking : Maybe Int
    , invalidCodes : List Int
    }


type LoginForm
    = EnterEmail EnterEmail2
    | EnterLoginCode EnterLoginCode2


type Msg
    = TypedEmail String
    | PressedSubmitEmail
    | TypedLoginCode String
    | PressedCancelLogin
