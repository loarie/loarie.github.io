import * as Crypto from 'expo-crypto';
import * as SecureStore from 'expo-secure-store';

import {
  INAT_CLIENT_ID,
  INAT_REDIRECT_URI,
  INAT_SITE_URL,
} from '../config';

const ACCESS_TOKEN_KEY = 'inat_oauth_access_token';
const JWT_KEY = 'inat_jwt_api_token';
const JWT_FETCHED_AT_KEY = 'inat_jwt_fetched_at';

// iNaturalist JWTs are valid for 24 hours. Refresh a bit early to be safe.
const JWT_MAX_AGE_MS = 20 * 60 * 60 * 1000;

// The PKCE code_verifier only needs to live in memory for the span of a
// single login attempt (generate it -> build the authorize URL -> use it
// to redeem whatever code comes back). No need to persist it to disk.
let pendingCodeVerifier = null;

function base64UrlFromBase64(base64) {
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function bytesToHex(bytes) {
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
}

// PKCE (RFC 7636): the app generates a random secret (code_verifier) and
// sends its SHA-256 hash (code_challenge) with the authorize request.
// Later, redeeming the code requires presenting the original verifier,
// which proves this app made the original request without needing a
// static, extractable client secret.
async function generatePkcePair() {
  const randomBytes = await Crypto.getRandomBytesAsync(32);
  // 64 hex chars satisfies the code_verifier spec (43-128 chars, from the
  // unreserved character set) without needing a base64 encoder for raw
  // bytes -- hex digits are already all valid, allowed characters.
  const codeVerifier = bytesToHex(randomBytes);
  const digestBase64 = await Crypto.digestStringAsync(
    Crypto.CryptoDigestAlgorithm.SHA256,
    codeVerifier,
    { encoding: Crypto.CryptoEncoding.BASE64 },
  );
  const codeChallenge = base64UrlFromBase64(digestBase64);
  return { codeVerifier, codeChallenge };
}

export async function getAuthorizeUrl() {
  const { codeVerifier, codeChallenge } = await generatePkcePair();
  pendingCodeVerifier = codeVerifier;

  const params = {
    client_id: INAT_CLIENT_ID,
    redirect_uri: INAT_REDIRECT_URI,
    response_type: 'code',
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
  };
  const query = Object.entries(params)
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
    .join('&');
  return `${INAT_SITE_URL}/oauth/authorize?${query}`;
}

// Step 2 of the OAuth Authorization Code flow: trade the "code" query
// param the redirect came back with for an OAuth access token, proving
// this app made the original authorize request via the PKCE verifier
// instead of a client secret.
export async function exchangeCodeForAccessToken(code) {
  if (!pendingCodeVerifier) {
    throw new Error('No PKCE code_verifier available -- call getAuthorizeUrl() first.');
  }
  const codeVerifier = pendingCodeVerifier;
  pendingCodeVerifier = null;

  const response = await fetch(`${INAT_SITE_URL}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: INAT_CLIENT_ID,
      code,
      grant_type: 'authorization_code',
      redirect_uri: INAT_REDIRECT_URI,
      code_verifier: codeVerifier,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Failed to exchange code for token (${response.status}): ${text}`);
  }

  const data = await response.json();
  return data.access_token;
}

// Step 3: trade the OAuth access token for a short-lived JWT. The JWT
// (not the OAuth token) is what the api.inaturalist.org/v1 API expects
// in the Authorization header.
export async function fetchJwtApiToken(accessToken) {
  const response = await fetch(`${INAT_SITE_URL}/users/api_token`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
    },
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Failed to fetch JWT api_token (${response.status}): ${text}`);
  }

  const data = await response.json();
  return data.api_token;
}

// Runs the full code -> access token -> JWT chain and persists everything.
export async function completeLogin(code) {
  const accessToken = await exchangeCodeForAccessToken(code);
  await SecureStore.setItemAsync(ACCESS_TOKEN_KEY, accessToken);

  const jwt = await fetchJwtApiToken(accessToken);
  await SecureStore.setItemAsync(JWT_KEY, jwt);
  await SecureStore.setItemAsync(JWT_FETCHED_AT_KEY, String(Date.now()));

  return jwt;
}

// Returns a JWT usable for API requests, refreshing it from the stored
// OAuth access token if it's missing or stale. Returns null if the user
// has never logged in.
export async function getValidJwt() {
  const accessToken = await SecureStore.getItemAsync(ACCESS_TOKEN_KEY);
  if (!accessToken) return null;

  const [storedJwt, fetchedAt] = await Promise.all([
    SecureStore.getItemAsync(JWT_KEY),
    SecureStore.getItemAsync(JWT_FETCHED_AT_KEY),
  ]);

  const age = fetchedAt ? Date.now() - Number(fetchedAt) : Infinity;
  if (storedJwt && age < JWT_MAX_AGE_MS) {
    return storedJwt;
  }

  const jwt = await fetchJwtApiToken(accessToken);
  await SecureStore.setItemAsync(JWT_KEY, jwt);
  await SecureStore.setItemAsync(JWT_FETCHED_AT_KEY, String(Date.now()));
  return jwt;
}

export async function isLoggedIn() {
  const accessToken = await SecureStore.getItemAsync(ACCESS_TOKEN_KEY);
  return !!accessToken;
}

export async function logout() {
  await Promise.all([
    SecureStore.deleteItemAsync(ACCESS_TOKEN_KEY),
    SecureStore.deleteItemAsync(JWT_KEY),
    SecureStore.deleteItemAsync(JWT_FETCHED_AT_KEY),
  ]);
}
