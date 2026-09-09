import React from 'react';
import {
  Linking, StyleSheet, Text, TouchableOpacity, View,
} from 'react-native';

import { INAT_SIGNUP_URL } from '../config';

export default function WelcomeScreen({ navigation }) {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>iNat Example Client</Text>
      <Text style={styles.subtitle}>
        Sign in to your iNaturalist account to post an observation.
      </Text>

      <TouchableOpacity
        style={styles.primaryButton}
        onPress={() => navigation.navigate('Login')}
      >
        <Text style={styles.primaryButtonText}>Log In</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.secondaryButton}
        onPress={() => Linking.openURL(INAT_SIGNUP_URL)}
      >
        <Text style={styles.secondaryButtonText}>Sign Up</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1, padding: 24, justifyContent: 'center', alignItems: 'center',
  },
  title: {
    fontSize: 24, fontWeight: '700', marginBottom: 8, textAlign: 'center',
  },
  subtitle: {
    fontSize: 15, color: '#666', textAlign: 'center', marginBottom: 40,
  },
  primaryButton: {
    backgroundColor: '#74ac00',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
    width: '100%',
    marginBottom: 12,
  },
  primaryButtonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  secondaryButton: {
    borderWidth: 1,
    borderColor: '#74ac00',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
    width: '100%',
  },
  secondaryButtonText: { color: '#74ac00', fontSize: 16, fontWeight: '600' },
});
