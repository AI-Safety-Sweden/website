module User exposing (User, nameFromString)

{-| Someone who can log in to the admin site. Only people in the user table can log in; there's no sign up.
-}

import EmailAddress exposing (EmailAddress)
import Time


type alias User =
    { name : String
    , email : EmailAddress
    , createdAt : Time.Posix
    }


nameFromString : String -> Result String String
nameFromString text =
    let
        trimmed : String
        trimmed =
            String.trim text
    in
    if trimmed == "" then
        Err "Name can't be empty"

    else if String.length trimmed > 100 then
        Err "Name is too long"

    else
        Ok trimmed
