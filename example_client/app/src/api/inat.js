import { INAT_API_URL } from '../config';

// The v1 API expects the JWT directly in the Authorization header
// (no "Bearer " prefix -- that's only used when talking to
// www.inaturalist.org to fetch the JWT itself).
function authHeaders(jwt, extra = {}) {
  return { Authorization: jwt, ...extra };
}

async function handleJsonResponse(response) {
  const text = await response.text();
  if (!response.ok) {
    console.warn(`iNaturalist API ${response.status} raw body:`, text);
    let message = text;
    try {
      const data = text ? JSON.parse(text) : null;
      message = data?.error || data?.errors || message;
    } catch {
      // body wasn't JSON, fall back to raw text below
    }
    throw new Error(`iNaturalist API error (${response.status}): ${JSON.stringify(message)}`);
  }
  return text ? JSON.parse(text) : null;
}

function sleep(ms) {
  return new Promise((resolve) => { setTimeout(resolve, ms); });
}

// iNaturalist has a known bug (seen elsewhere in this app around creating
// observations too) where some v1 API reads throw a generic, contentless
// 500 for records that haven't finished being indexed into Elasticsearch
// yet, rather than a clean "not ready" response. Retrying briefly usually
// resolves it once indexing catches up. Scoped to this exact error
// signature so a genuine failure (e.g. a real 404) still fails fast.
export function isPhantomServerError(err) {
  return /iNaturalist API error \(500\): "Error"/.test(err?.message || '');
}

export async function retryOnPhantomServerError(fn, { timeoutMs = 15000, intervalMs = 2000 } = {}) {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    try {
      return await fn();
    } catch (err) {
      if (!isPhantomServerError(err) || Date.now() >= deadline) throw err;
      await sleep(intervalMs);
    }
  }
}

export async function getCurrentUser(jwt) {
  const response = await fetch(`${INAT_API_URL}/users/me`, {
    headers: authHeaders(jwt, { Accept: 'application/json' }),
  });
  const data = await handleJsonResponse(response);
  return data.results?.[0] ?? null;
}

// Creates an observation. `fields` maps directly to iNaturalist's
// `observation` params, e.g.:
//   { species_guess, description, observed_on_string,
//     latitude, longitude, positional_accuracy }
export async function createObservation(jwt, fields) {
  const response = await fetch(`${INAT_API_URL}/observations`, {
    method: 'POST',
    headers: authHeaders(jwt, {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    }),
    body: JSON.stringify({ observation: fields }),
  });
  const data = await handleJsonResponse(response);
  return data.results?.[0] ?? data;
}

// species_guess is free-text the observer typed in and is often blank,
// e.g. when the observation was identified later by someone else or by
// computer vision rather than guessed at creation time. Fall back to the
// taxon's common/scientific name in that case.
export function observationDisplayName(observation) {
  return observation.species_guess
    || observation.taxon?.preferred_common_name
    || observation.taxon?.name
    || 'Unknown';
}

// Fetches a single observation by id.
//
// Deliberately uses the search endpoint's `id` filter (GET
// /observations?id=X) rather than the path-based GET /observations/:id.
// The latter has a server-side bug: its response includes an
// `application` block describing which OAuth app created the
// observation, and building that block throws an unhandled exception for
// at least some apps (reproduced consistently for observations created
// through this app's OAuth application, both via this API endpoint and
// on the inaturalist.org website itself). The search endpoint's response
// omits that block and works fine for the same records.
export async function getObservation(jwt, id) {
  const response = await fetch(`${INAT_API_URL}/observations?id=${id}`, {
    headers: authHeaders(jwt, { Accept: 'application/json' }),
  });
  const data = await handleJsonResponse(response);
  return data.results?.[0] ?? null;
}

// Updates an observation. `fields` maps directly to iNaturalist's
// `observation` params, same shape as createObservation.
export async function updateObservation(jwt, id, fields) {
  const response = await fetch(`${INAT_API_URL}/observations/${id}`, {
    method: 'PUT',
    headers: authHeaders(jwt, {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    }),
    body: JSON.stringify({ observation: fields }),
  });
  const data = await handleJsonResponse(response);
  return data.results?.[0] ?? data;
}

export async function deleteObservation(jwt, id) {
  const response = await fetch(`${INAT_API_URL}/observations/${id}`, {
    method: 'DELETE',
    headers: authHeaders(jwt, { Accept: 'application/json' }),
  });
  await handleJsonResponse(response);
}

// Fetches a user's most recent observations, photos included, for
// display in a grid.
export async function listRecentObservations(jwt, userId, perPage = 30) {
  const response = await fetch(
    `${INAT_API_URL}/observations?user_id=${userId}&order_by=created_at&order=desc&per_page=${perPage}`,
    { headers: authHeaders(jwt, { Accept: 'application/json' }) },
  );
  const data = await handleJsonResponse(response);
  return data?.results ?? [];
}

async function fetchMostRecentObservation(jwt, userId) {
  const response = await fetch(
    `${INAT_API_URL}/observations?user_id=${userId}&order_by=created_at&order=desc&per_page=1`,
    { headers: authHeaders(jwt, { Accept: 'application/json' }) },
  );
  const data = await handleJsonResponse(response);
  return data?.results?.[0] ?? null;
}

// iNaturalist's API has a known bug where an observation create can
// succeed server-side (the record is committed to the database) but the
// HTTP response still comes back as a generic 500. The search endpoint
// used here to look the observation back up is backed by Elasticsearch,
// which is indexed asynchronously after the write, so a freshly-created
// observation can take a few seconds to show up. Poll for a bit rather
// than checking once. `sinceMs` should be a timestamp captured just
// before the original create attempt.
export async function findJustCreatedObservation(jwt, userId, speciesGuess, sinceMs) {
  const deadline = Date.now() + 15000;
  for (;;) {
    const candidate = await fetchMostRecentObservation(jwt, userId);
    const createdAtMs = candidate ? new Date(candidate.created_at).getTime() : null;
    const isMatch = candidate
      && candidate.species_guess === speciesGuess
      && createdAtMs >= sinceMs - 3000;
    if (isMatch) return candidate;
    if (Date.now() >= deadline) return null;
    await sleep(2000);
  }
}

// Attaches a photo to an existing observation. `photo` is
// { uri, name, type } as returned by expo-image-picker.
//
// This deliberately uses XMLHttpRequest instead of fetch: Expo SDK 57's
// global fetch is backed by a new WinterCG-compliant implementation that
// doesn't support React Native's classic { uri, name, type } FormData file
// shape (throws "Unsupported FormDataPart implementation"). XHR is RN's
// original networking API and still handles it correctly.
export function addObservationPhoto(jwt, observationId, photo) {
  return new Promise((resolve, reject) => {
    const body = new FormData();
    body.append('observation_photo[observation_id]', String(observationId));
    body.append('file', {
      uri: photo.uri,
      name: photo.name || 'photo.jpg',
      type: photo.type || 'image/jpeg',
    });

    const xhr = new XMLHttpRequest();
    xhr.open('POST', `${INAT_API_URL}/observation_photos`);
    xhr.setRequestHeader('Authorization', jwt);
    xhr.setRequestHeader('Accept', 'application/json');
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve(xhr.responseText ? JSON.parse(xhr.responseText) : null);
      } else {
        console.warn(`iNaturalist API ${xhr.status} raw body:`, xhr.responseText);
        reject(new Error(`iNaturalist API error (${xhr.status}): ${xhr.responseText}`));
      }
    };
    xhr.onerror = () => reject(new Error('Network error while uploading photo'));
    xhr.send(body);
  });
}
