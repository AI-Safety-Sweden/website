module LamderaRPC exposing (HttpBody(..), HttpRequest, RPCResult(..), process)

{-| The parts of Lamdera's HTTP RPC glue (from at-chat) that this app uses. The Lamdera compiler
calls `process` for requests to `/_r/<endpoint>`, which then calls `RPC.lamdera_handleEndpoints`.
-}

import Dict exposing (Dict)
import Json.Decode as D
import Lamdera.Json as Json
import Types exposing (BackendModel)


type RPCResult
    = ResultJson Json.Value
    | ResultRaw Int String (List ( String, String )) HttpBody


type HttpBody
    = BodyBytes (List Int)
    | BodyJson Json.Value
    | BodyString String


type alias HttpRequest =
    { sessionId : String
    , endpoint : String
    , requestId : String
    , headers : Dict String String
    , body : HttpBody
    }


requestDecoder : D.Decoder HttpRequest
requestDecoder =
    D.map5 HttpRequest
        (Json.field "s" Json.decoderString)
        (Json.field "e" Json.decoderString)
        (Json.field "r" Json.decoderString)
        (Json.field "h" (D.dict Json.decoderString))
        (D.oneOf
            [ Json.field "i" (Json.decoderList Json.decoderInt |> D.map BodyBytes)
            , Json.field "j" (Json.decoderValue |> D.map BodyJson)
            , Json.field "st" (Json.decoderString |> D.map BodyString)
            ]
        )


process :
    (String -> String -> Cmd msg)
    -> (Json.Value -> Cmd msg)
    -> Json.Value
    -> (Json.Value -> HttpRequest -> BackendModel -> ( RPCResult, BackendModel, Cmd msg ))
    -> { a | userModel : BackendModel }
    -> ( { a | userModel : BackendModel }, Cmd msg )
process log rpcOut rawReq handler model =
    case Json.decodeValue requestDecoder rawReq of
        Ok request ->
            let
                ( result, newUserModel, newCmds ) =
                    handler rawReq request model.userModel

                resolveRpc : Int -> String -> List ( String, String ) -> ( String, Json.Value ) -> Cmd msg
                resolveRpc statusCodeInt statusText headers body =
                    rpcOut
                        (Json.object
                            [ ( "t", Json.string "qr" )
                            , ( "r", Json.string request.requestId )
                            , ( "c", Json.int statusCodeInt )
                            , ( "ct", Json.string statusText )
                            , ( "h", headers |> List.map (\( key, val ) -> ( key, Json.string val )) |> Json.object )
                            , body
                            ]
                        )
            in
            case result of
                ResultJson value ->
                    ( { model | userModel = newUserModel }
                    , Cmd.batch [ resolveRpc 200 "OK" [] ( "v", value ), newCmds ]
                    )

                ResultRaw statusCode statusText headers httpBody ->
                    ( { model | userModel = newUserModel }
                    , Cmd.batch
                        [ resolveRpc
                            statusCode
                            statusText
                            headers
                            (case httpBody of
                                BodyBytes intList ->
                                    ( "i", Json.list Json.int intList )

                                BodyJson value ->
                                    ( "v", value )

                                BodyString value ->
                                    ( "vs", Json.string value )
                            )
                        , newCmds
                        ]
                    )

        Err _ ->
            ( model, log "rpcIn failed to decode requestJson" "" )
