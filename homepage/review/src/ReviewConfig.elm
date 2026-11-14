module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

The rules are the ones from at-chat that aren't specific to that app. NoUnused.Dependencies
is left out because elm-pages needs dependencies that no module in app/ imports.

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
        -- elm-pages needs Shared.Msg even though nothing sends it yet
        |> Review.Rule.ignoreErrorsForFiles [ "app/Shared.elm" ]
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
    , NoUnused.Modules.rule
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
    , EncoderDecoderNaming.rule
    , NoBrokenParserFunctions.rule
    ]
        |> List.map
            (\rule ->
                rule
                    |> Review.Rule.ignoreErrorsForDirectories [ ".elm-pages", "elm-stuff" ]
                    -- Boilerplate from the elm-pages starter, shaped by what elm-pages expects
                    |> Review.Rule.ignoreErrorsForFiles [ "app/Api.elm", "app/Effect.elm", "app/ErrorPage.elm", "app/View.elm" ]
            )
