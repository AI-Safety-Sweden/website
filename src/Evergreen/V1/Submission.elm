module Evergreen.V1.Submission exposing (..)

import Time


type Answer
    = TextAnswer String
    | ListAnswer (List String)


type alias Submission =
    { submittedAt : Time.Posix
    , answers : List ( String, Answer )
    }
