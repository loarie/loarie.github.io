import React, {
  useCallback, useEffect, useState,
} from 'react';
import {
  ActivityIndicator, StyleSheet, Text, View,
} from 'react-native';
import { WebView } from 'react-native-webview';

import { getAuthorizeUrl } from '../api/auth';
import { INAT_REDIRECT_URI } from '../config';
import { useAuth } from '../context/AuthContext';

function extractQueryParam(url, name) {
  const match = url.match(new RegExp(`[?&]${name}=([^&#]*)`));
  return match ? decodeURIComponent(match[1]) : null;
}

export default function LoginScreen() {
  const { login } = useAuth();
  const [exchanging, setExchanging] = useState(false);
  const [error, setError] = useState(null);
  const [authorizeUrl, setAuthorizeUrl] = useState(null);

  useEffect(() => {
    getAuthorizeUrl()
      .then(setAuthorizeUrl)
      .catch((err) => {
        console.warn('Failed to build authorize URL', err);
        setError(err.message || 'Could not start login.');
      });
  }, []);

  // Called for every navigation the WebView is about to make. We watch
  // for it about to load our redirect_uri -- iNaturalist never actually
  // needs to serve that page, we just need to see the "code" query param
  // iNaturalist attaches to it and stop the WebView from loading it.
  const handleShouldStartLoad = useCallback((request) => {
    const { url } = request;
    if (!url.startsWith(INAT_REDIRECT_URI)) {
      return true;
    }

    const code = extractQueryParam(url, 'code');
    const oauthError = extractQueryParam(url, 'error');

    if (oauthError) {
      setError(`Authorization was not granted (${oauthError}).`);
    } else if (code) {
      setExchanging(true);
      login(code).catch((err) => {
        console.warn('Login failed', err);
        setError(err.message || 'Login failed.');
        setExchanging(false);
      });
    }

    return false;
  }, [login]);

  if (exchanging) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" />
        <Text style={styles.status}>Signing in to iNaturalist...</Text>
      </View>
    );
  }

  if (!authorizeUrl) {
    return (
      <View style={styles.center}>
        {error ? (
          <View style={styles.errorBanner}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        ) : (
          <ActivityIndicator size="large" />
        )}
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {error ? (
        <View style={styles.errorBanner}>
          <Text style={styles.errorText}>{error}</Text>
        </View>
      ) : null}
      <WebView
        source={{ uri: authorizeUrl }}
        onShouldStartLoadWithRequest={handleShouldStartLoad}
        incognito
        startInLoadingState
        renderLoading={() => (
          <View style={styles.center}>
            <ActivityIndicator size="large" />
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: {
    flex: 1, alignItems: 'center', justifyContent: 'center',
  },
  status: { marginTop: 12, fontSize: 16, color: '#333' },
  errorBanner: { backgroundColor: '#fdecea', padding: 12 },
  errorText: { color: '#b3261e' },
});
