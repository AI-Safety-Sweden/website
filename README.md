# AI Safety Sweden website

This repo holds two apps:

- `homepage/`: the public homepage, an [elm-pages](https://elm-pages.com) v3 site hosted on Netlify (`netlify.toml` points Netlify at that folder).
- The repo root: the admin site, a Lamdera app that stores signups from the homepage's form. Lamdera needs `elm.json` and `src/` at the top level, so it lives there.

## Homepage (homepage/)

```sh
cd homepage
npm install
npm start        # dev server at http://localhost:1234
npm run build    # static site in dist/
```

- `app/Route/Index.elm`: the homepage (hero, next event card, about section). The next event's details are in `data`.
- `app/Route/Join.elm`: the signup form, which posts to `netlify/functions/join.mjs`.
- `app/Shared.elm`: the layout shared by every page (header nav and footer).
- `app/Site.elm`: site-wide config such as the canonical URL.
- `elm-pages.config.mjs`: head tags (Google Fonts and the stylesheet).

## Admin site (repo root)

A Lamdera app, deployed at https://ai-safety-sweden.lamdera.app. It stores signups from the
form at aisafetysweden.se/join and lets the people in its user table read them.

### How signups get here

The homepage's form posts to its Netlify function (`homepage/netlify/functions/join.mjs`), which forwards the signup as JSON to
`https://ai-safety-sweden.lamdera.app/_r/signup` (handled in `src/RPC.elm`). The JSON carries a
shared secret, which must match `Env.signupSecret` here and `SIGNUP_SECRET` on Netlify.

### Logging in

Only email addresses in the user table can log in. They get an 8-digit code by email, sent with
Postmark. Until a Postmark API key has been saved on the admin page, no emails can be sent, so the
first user logs in with the recovery password instead (the same one as at-chat's). After that, change
the first user's email (`a@a.aa`) to your own and add a Postmark key. Once a key is set, the
recovery password stops working.

Login emails come from `no-reply@aisafetysweden.se`, so that address (or the domain) needs to be a
verified sender in Postmark.

### Environment variables (Lamdera dashboard)

- `isProduction_`: `True`
- `secretKey`: a long random string, used to generate login codes
- `signupSecret`: a long random string, the same as `SIGNUP_SECRET` on Netlify

### Building

```
npm install
python3 scripts/populate-elm-cache.py elm.json review/elm.json homepage/elm.json homepage/review/elm.json
npx lamdera make src/Frontend.elm src/Backend.elm src/RPC.elm --output /dev/null
npx elm-format src/ --yes
npx elm-review --compiler "$(realpath node_modules/.bin/lamdera)"
```

`npx lamdera live` runs it locally on port 8000. Login codes are printed to the browser console there.
