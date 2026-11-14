module Env exposing (isProduction, secretKey, signupSecret)

{-| Set these in the Lamdera dashboard for production. The values here are only used locally.
-}


isProduction_ : String
isProduction_ =
    "False"


isProduction : Bool
isProduction =
    isProduction_ == "True"


{-| Used to generate login codes. Set it to a long random string.
-}
secretKey : String
secretKey =
    "123ABCabc"


{-| The website's Netlify function sends this with each signup (its SIGNUP\_SECRET environment
variable), so that only the website can add signups.
-}
signupSecret : String
signupSecret =
    "local-signup-secret"
