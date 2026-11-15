module Evergreen.V1.LoginForm exposing (..)

import Evergreen.V1.EmailAddress


type EmailProblem
    = RateLimited
    | NotAllowed


type alias EnterEmail2 =
    { email : String
    , pressedSubmit : Bool
    , problem : Maybe EmailProblem
    }


type alias EnterLoginCode2 =
    { sentTo : Evergreen.V1.EmailAddress.EmailAddress
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
