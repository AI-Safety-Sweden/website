module Id exposing (Id, SubmissionId, UserId, fromInt, toInt)


type Id a
    = Id Int


type UserId
    = UserId Never


type SubmissionId
    = SubmissionId Never


fromInt : Int -> Id a
fromInt =
    Id


toInt : Id a -> Int
toInt (Id int) =
    int
