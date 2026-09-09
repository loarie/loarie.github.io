# iNat Example Client

A simple Expo (React Native) app that signs a user in to their iNaturalist
account via OAuth and lets them post a new observation, optionally with a
photo and location.

## How it works

1. **Login** (`src/screens/LoginScreen.js`) opens iNaturalist's OAuth
   authorize page in a WebView. When the user logs in and grants access,
   iNaturalist redirects to the app's registered callback URL
   (`http://www.scottloarie.com/example_client`) with a `?code=...` param.
   The WebView intercepts that navigation before it loads and pulls out the
   code.
2. **Token exchange** (`src/api/auth.js`) trades that code for an OAuth
   access token (`POST /oauth/token`), then trades the access token for a
   short-lived (24h) JWT (`GET /users/api_token`). Both are stored with
   `expo-secure-store`; the JWT is refreshed automatically when it's stale.
   The app authenticates itself for the token exchange with PKCE (a
   per-login `code_verifier`/`code_challenge` pair generated with
   `expo-crypto`) rather than a client secret — see the security note
   below for why.
3. **API calls** (`src/api/inat.js`) use the JWT in the `Authorization`
   header to call `api.inaturalist.org/v1` — fetching the current user and
   posting new observations / photos.

## Running it

```sh
cd app
npm install   # already run
npm start     # then press i / a, or scan the QR code with Expo Go
```

This app only uses modules supported by Expo Go (`react-native-webview`,
`expo-secure-store`, `expo-image-picker`, `expo-location`, `expo-crypto`,
`expo-image-manipulator`), so you don't need a custom dev client to try it.

Requires Node 22+ per Expo SDK 57 (developed here against Node 20, which
mostly works but may print warnings).

## About the callback page

`../index.html` (served at `http://www.scottloarie.com/example_client`
once this repo is published) is just a fallback landing page — the app
never actually needs it to load, since the WebView intercepts the redirect
first. It's useful for confirming the OAuth app config works if you paste
the authorize URL into a normal browser.

## Security note: PKCE instead of a client secret

This app's OAuth application is registered as "public" (non-confidential,
no client secret). A static secret embedded in a mobile app bundle isn't
truly secret — anyone can extract it from the compiled app via basic
reverse engineering, which matters once an app is actually distributed
rather than just run locally.

Instead, `src/api/auth.js` implements PKCE (RFC 7636): before each login,
it generates a random `code_verifier`, sends its SHA-256 hash as the
`code_challenge` with the `/oauth/authorize` request, and later presents
the original `code_verifier` when redeeming the authorization code at
`/oauth/token`. This proves the token request came from the same app
instance that started the login, without any long-lived secret that could
leak from the client.
