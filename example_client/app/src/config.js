// iNaturalist OAuth application credentials.
// Registered at https://www.inaturalist.org/oauth/applications
//
// This is a "public" (non-confidential) OAuth application -- it has no
// client secret. Instead it proves its identity per-login using PKCE
// (see src/api/auth.js), which is the correct approach for a client
// whose code ships to end-user devices, since a static secret embedded
// in a mobile app bundle can always be extracted.
export const INAT_CLIENT_ID = '5wN71-j3u-0eA5fqfSsBJ4wQuWDPNL3m-I7GMKgEU3I';

// Must exactly match the callback URL registered for the application.
export const INAT_REDIRECT_URI = 'http://www.scottloarie.com/example_client';

// The main iNaturalist site handles OAuth and account-level endpoints
// (like exchanging an OAuth token for a JWT).
export const INAT_SITE_URL = 'https://www.inaturalist.org';

// The v1 REST API (a separate Node.js service) handles observations, users,
// taxa, etc. and is authenticated with the JWT obtained from INAT_SITE_URL.
export const INAT_API_URL = 'https://api.inaturalist.org/v1';

export const INAT_SIGNUP_URL = `${INAT_SITE_URL}/signup`;
