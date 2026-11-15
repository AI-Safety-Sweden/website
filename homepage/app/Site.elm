module Site exposing (config)

import BackendTask exposing (BackendTask)
import FatalError exposing (FatalError)
import Head
import SiteConfig exposing (SiteConfig)


config : SiteConfig
config =
    { canonicalUrl = "https://aisafetysweden.se"
    , head = head
    }


head : BackendTask FatalError (List Head.Tag)
head =
    [ Head.metaName "viewport" (Head.raw "width=device-width,initial-scale=1")
    , Head.sitemapLink "/sitemap.xml"
    , Head.nonLoadingNode "link"
        [ ( "rel", Head.raw "icon" )
        , ( "type", Head.raw "image/svg+xml" )
        , ( "href", Head.raw "/favicon.svg" )
        ]
    ]
        |> BackendTask.succeed
