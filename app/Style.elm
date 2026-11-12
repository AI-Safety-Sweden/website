module Style exposing (accent, background, border, borderStrong, chrome, container, fontDisplay, surface, textFaint, textMuted, textStrong)

import Html
import Html.Attributes as Attr


accent : String
accent =
    "#3B5E4C"


background : String
background =
    "#FFFFFF"


chrome : String
chrome =
    "#E6EEE9"


surface : String
surface =
    "#F3F6F4"


border : String
border =
    "#E1E7E3"


borderStrong : String
borderStrong =
    "#C9D3CD"


textStrong : String
textStrong =
    "#0B100D"


textMuted : String
textMuted =
    "#3F4843"


textFaint : String
textFaint =
    "#626B66"


fontDisplay : String
fontDisplay =
    "'Space Grotesk', system-ui, sans-serif"


container : List (Html.Attribute msg)
container =
    [ Attr.style "max-width" "1280px"
    , Attr.style "margin" "0 auto"
    , Attr.style "padding-inline" "clamp(20px, 5vw, 32px)"
    ]
