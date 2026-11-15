module Evergreen.V1.User exposing (..)

import Evergreen.V1.EmailAddress
import Time


type alias User =
    { name : String
    , email : Evergreen.V1.EmailAddress.EmailAddress
    , createdAt : Time.Posix
    }
