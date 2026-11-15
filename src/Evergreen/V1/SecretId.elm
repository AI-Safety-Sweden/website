module Evergreen.V1.SecretId exposing (..)


type ServerSecret
    = ServerSecret Never


type SecretId a
    = SecretId String
