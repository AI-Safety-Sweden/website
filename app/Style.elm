module Style exposing (accent, background, border, borderButton, borderStrong, container, fontBody, fontDisplay, surface, text, textFaint, textMuted, textStrong)

import Html
import Html.Attributes as Attr


accent : String
accent =
    "#F5C542"


background : String
background =
    "#0B1020"


surface : String
surface =
    "#111833"


border : String
border =
    "#1E2642"


borderStrong : String
borderStrong =
    "#273150"


borderButton : String
borderButton =
    "#3A4466"


textStrong : String
textStrong =
    "#F2F4F9"


text : String
text =
    "#E9ECF4"


textMuted : String
textMuted =
    "#B8C0D4"


textFaint : String
textFaint =
    "#9BA4BC"


fontDisplay : String
fontDisplay =
    "'Space Grotesk', system-ui, sans-serif"


fontBody : String
fontBody =
    "'IBM Plex Sans', system-ui, sans-serif"


container : List (Html.Attribute msg)
container =
    [ Attr.style "max-width" "1280px"
    , Attr.style "margin" "0 auto"
    , Attr.style "padding-inline" "clamp(20px, 5vw, 32px)"
    ]
