module RPC exposing (lamdera_handleEndpoints)

{-| HTTP endpoints, reached at `/_r/<endpoint>`. Lamdera calls `lamdera_handleEndpoints` for them.
-}

import Env
import Id
import Json.Decode
import Json.Encode
import LamderaRPC exposing (HttpBody(..), HttpRequest, RPCResult(..))
import SeqDict
import Submission
import Task
import Types exposing (BackendModel, BackendMsg(..))


lamdera_handleEndpoints : Json.Encode.Value -> HttpRequest -> BackendModel -> ( RPCResult, BackendModel, Cmd BackendMsg )
lamdera_handleEndpoints _ request model =
    case request.endpoint of
        "signup" ->
            signup request model

        _ ->
            ( ResultRaw 404 "Not Found" [] (BodyString "Unknown endpoint"), model, Cmd.none )


{-| The website's signup form posts to its Netlify function, which forwards the signup here.
-}
signup : HttpRequest -> BackendModel -> ( RPCResult, BackendModel, Cmd BackendMsg )
signup request model =
    case request.body of
        BodyJson json ->
            case Json.Decode.decodeValue Submission.decoder json of
                Ok { secret, submission } ->
                    if secret == Env.signupSecret then
                        let
                            submissionId : Id.Id Id.SubmissionId
                            submissionId =
                                SeqDict.keys model.submissions
                                    |> List.map Id.toInt
                                    |> List.maximum
                                    |> Maybe.withDefault -1
                                    |> (+) 1
                                    |> Id.fromInt
                        in
                        ( ResultJson (Json.Encode.object [ ( "ok", Json.Encode.bool True ) ])
                        , { model | submissions = SeqDict.insert submissionId submission model.submissions }
                        , Task.perform (\() -> SubmissionReceived submissionId) (Task.succeed ())
                        )

                    else
                        ( ResultRaw 401 "Unauthorized" [] (BodyString "Wrong secret"), model, Cmd.none )

                Err error ->
                    ( ResultRaw 400 "Bad Request" [] (BodyString (Json.Decode.errorToString error)), model, Cmd.none )

        _ ->
            ( ResultRaw 400 "Bad Request" [] (BodyString "Expected a JSON body"), model, Cmd.none )
