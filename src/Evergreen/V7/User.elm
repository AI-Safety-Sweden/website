module Evergreen.V7.User exposing (..)

import Evergreen.V7.EmailAddress
import Time


type alias User =
    { name : String
    , email : Evergreen.V7.EmailAddress.EmailAddress
    , createdAt : Time.Posix
    }
