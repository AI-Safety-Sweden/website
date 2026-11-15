module Style exposing (accent, background, border, borderStrong, button, date, dateTime, error, smallButton, surface, textFaint, textMuted, textStrong)

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events
import Time


accent : String
accent =
    "#3B5E4C"


background : String
background =
    "#FFFFFF"


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


error : String
error =
    "#B3261E"


button : msg -> String -> Html msg
button onPress label =
    Html.button
        [ Html.Events.onClick onPress
        , Attr.type_ "button"
        , Attr.style "padding" "10px 18px"
        , Attr.style "border" "none"
        , Attr.style "border-radius" "8px"
        , Attr.style "background" accent
        , Attr.style "color" background
        , Attr.style "font" "inherit"
        , Attr.style "font-weight" "600"
        , Attr.style "cursor" "pointer"
        ]
        [ Html.text label ]


smallButton : msg -> String -> Html msg
smallButton onPress label =
    Html.button
        [ Html.Events.onClick onPress
        , Attr.type_ "button"
        , Attr.style "padding" "4px 10px"
        , Attr.style "border" ("1px solid " ++ borderStrong)
        , Attr.style "border-radius" "6px"
        , Attr.style "background" background
        , Attr.style "color" textStrong
        , Attr.style "font" "inherit"
        , Attr.style "font-size" "14px"
        , Attr.style "cursor" "pointer"
        ]
        [ Html.text label ]


date : Time.Zone -> Time.Posix -> String
date zone time =
    String.fromInt (Time.toYear zone time)
        ++ "-"
        ++ pad (monthNumber (Time.toMonth zone time))
        ++ "-"
        ++ pad (Time.toDay zone time)


dateTime : Time.Zone -> Time.Posix -> String
dateTime zone time =
    date zone time ++ " " ++ pad (Time.toHour zone time) ++ ":" ++ pad (Time.toMinute zone time)


pad : Int -> String
pad int =
    String.padLeft 2 '0' (String.fromInt int)


monthNumber : Time.Month -> Int
monthNumber month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12
