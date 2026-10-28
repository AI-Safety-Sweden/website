# Sweden AI Safety website

Homepage for the Sweden AI Safety group in Stockholm, built with [elm-pages](https://elm-pages.com) v3.

## Development

```sh
npm install
npm start        # dev server at http://localhost:1234
npm run build    # static site in dist/
```

## Where things live

- `app/Route/Index.elm`: the homepage (hero, next event card, about section). The next event's details are in `data`.
- `app/Shared.elm`: the layout shared by every page (header nav and footer).
- `app/Site.elm`: site-wide config such as the canonical URL.
- `style.css`: all styles, including the colour and font tokens.
- `elm-pages.config.mjs`: head tags (Google Fonts and the stylesheet).
