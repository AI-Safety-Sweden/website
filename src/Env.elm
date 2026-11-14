module Env exposing (adminEmail, isProduction, postmarkApiKey, secretKey, signupSecret)

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


{-| This email can always log in, and adds others in the user table.
-}
adminEmail : String
adminEmail =
    "admin@example.com"


{-| The Postmark server API token used to send login codes. Without it no login emails get sent
(locally, the login code is printed to the browser console instead).
-}
postmarkApiKey : String
postmarkApiKey =
    ""
