module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

The rules are the ones from at-chat that aren't specific to that app.

-}

import Docs.ReviewAtDocs
import EncoderDecoderNaming
import NoBrokenParserFunctions
import NoConfusingPrefixOperator
import NoDebug.TodoOrToString
import NoExposingEverything
import NoImportingEverything
import NoMissingTypeAnnotation
import NoMissingTypeConstructor
import NoMissingTypeExpose
import NoModuleOnExposedNames
import NoSimpleLetBody
import NoStaleReferences
import NoUnused.CustomTypeConstructors
import NoUnused.Exports
import NoUnused.Modules
import NoUnused.Parameters
import NoUnused.Patterns
import NoUnused.Variables
import Review.Rule exposing (Rule)
import ReviewPipelineStyles
import ReviewPipelineStyles.Fixes
import Simplify


config : List Rule
config =
    [ NoStaleReferences.rule
    , NoUnused.CustomTypeConstructors.rule []
    , NoUnused.Patterns.rule
    , Docs.ReviewAtDocs.rule
    , NoConfusingPrefixOperator.rule
    , NoDebug.TodoOrToString.rule
    , NoExposingEverything.rule
    , NoImportingEverything.rule []
    , NoMissingTypeAnnotation.rule
    , NoMissingTypeExpose.rule
    , NoSimpleLetBody.rule
    , NoUnused.Exports.rule
        -- app_ is for lamdera/program-test, and Lamdera calls LamderaRPC.process itself
        |> Review.Rule.ignoreErrorsForFiles [ "src/Frontend.elm", "src/Backend.elm", "src/LamderaRPC.elm", "src/RPC.elm" ]
    , NoUnused.Modules.rule
        -- Lamdera calls RPC.lamdera_handleEndpoints itself
        |> Review.Rule.ignoreErrorsForFiles [ "src/RPC.elm" ]
    , NoUnused.Parameters.rule
    , ReviewPipelineStyles.rule
        [ ReviewPipelineStyles.forbid ReviewPipelineStyles.leftPizzaPipelines
            |> ReviewPipelineStyles.andTryToFixThemBy ReviewPipelineStyles.Fixes.convertingToParentheticalApplication
            |> ReviewPipelineStyles.andCallThem "forbidden <| pipeline"
        , ReviewPipelineStyles.forbid ReviewPipelineStyles.leftCompositionPipelines
            |> ReviewPipelineStyles.andCallThem "forbidden << composition"
        , ReviewPipelineStyles.forbid ReviewPipelineStyles.rightCompositionPipelines
            |> ReviewPipelineStyles.andCallThem "forbidden >> composition"
        ]
    , Simplify.rule Simplify.defaults
    , NoModuleOnExposedNames.rule
    , NoMissingTypeConstructor.rule
    , NoUnused.Variables.rule
    , EncoderDecoderNaming.rule |> Review.Rule.ignoreErrorsForFiles [ "src/LamderaRPC.elm" ]
    , NoBrokenParserFunctions.rule
    ]
        |> List.map
            (\rule ->
                rule
                    |> Review.Rule.ignoreErrorsForDirectories [ "vendored", "elm-stuff" ]
            )
