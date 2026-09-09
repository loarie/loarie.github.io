import * as Crypto from 'expo-crypto';
import * as ImageManipulator from 'expo-image-manipulator';
import * as ImagePicker from 'expo-image-picker';
import * as Location from 'expo-location';
import React, { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Image,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';

import { addObservationPhoto, createObservation, findJustCreatedObservation } from '../api/inat';
import { useAuth } from '../context/AuthContext';

// iNaturalist's servers can't process HEIC images, and both the library
// picker and the camera can hand back HEIC on iOS depending on device
// settings. Always re-encode to JPEG locally before uploading.
async function toUploadableJpeg(uri) {
  const result = await ImageManipulator.manipulateAsync(uri, [], {
    compress: 0.8,
    format: ImageManipulator.SaveFormat.JPEG,
  });
  return result.uri;
}

function todayString() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export default function NewObservationScreen({ navigation }) {
  const { jwt, user } = useAuth();

  const [speciesGuess, setSpeciesGuess] = useState('');
  const [description, setDescription] = useState('');
  const [observedOn, setObservedOn] = useState(todayString());
  const [location, setLocation] = useState(null);
  const [locating, setLocating] = useState(false);
  const [photo, setPhoto] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const useCurrentLocation = async () => {
    setLocating(true);
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission needed', 'Location permission is required to attach a location.');
        return;
      }
      const position = await Location.getCurrentPositionAsync({});
      setLocation({
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: position.coords.accuracy,
      });
    } catch (err) {
      Alert.alert('Could not get location', err.message);
    } finally {
      setLocating(false);
    }
  };

  const pickPhoto = async () => {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      Alert.alert('Permission needed', 'Photo library permission is required to attach a photo.');
      return;
    }
    try {
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        quality: 0.8,
        // iOS can fail to load a photo's original HEIC representation
        // (e.g. when it's not fully downloaded from iCloud yet). Forcing
        // "compatible" mode makes it transcode to JPEG instead.
        preferredAssetRepresentationMode:
          ImagePicker.UIImagePickerPreferredAssetRepresentationMode.Compatible,
      });
      if (!result.canceled && result.assets?.[0]) {
        const jpegUri = await toUploadableJpeg(result.assets[0].uri);
        setPhoto({ uri: jpegUri, name: 'photo.jpg', type: 'image/jpeg' });
      }
    } catch (err) {
      console.warn('Failed to load picked photo', err);
      Alert.alert(
        'Could not load that photo',
        'iOS was unable to read that photo (this can happen with photos imported from another '
          + "app, e.g. Messages or WhatsApp). Try a different photo, or use \"Take Photo\" instead.",
      );
    }
  };

  const takePhoto = async () => {
    const permission = await ImagePicker.requestCameraPermissionsAsync();
    if (!permission.granted) {
      Alert.alert('Permission needed', 'Camera permission is required to take a photo.');
      return;
    }
    try {
      const result = await ImagePicker.launchCameraAsync({ quality: 0.8 });
      if (!result.canceled && result.assets?.[0]) {
        const jpegUri = await toUploadableJpeg(result.assets[0].uri);
        setPhoto({ uri: jpegUri, name: 'photo.jpg', type: 'image/jpeg' });
      }
    } catch (err) {
      console.warn('Failed to process captured photo', err);
      Alert.alert('Could not use that photo', err.message);
    }
  };

  const submit = async () => {
    if (!speciesGuess.trim()) {
      Alert.alert('Missing info', 'Please enter what you saw.');
      return;
    }
    setSubmitting(true);
    const trimmedSpeciesGuess = speciesGuess.trim();
    const attemptStartedAt = Date.now();
    try {
      let observation;
      try {
        observation = await createObservation(jwt, {
          uuid: Crypto.randomUUID(),
          species_guess: trimmedSpeciesGuess,
          description: description.trim() || undefined,
          observed_on_string: observedOn,
          ...(location
            ? {
              latitude: location.latitude,
              longitude: location.longitude,
              positional_accuracy: location.accuracy ?? undefined,
            }
            : {}),
        });
      } catch (createErr) {
        // iNaturalist has a known bug where a create can succeed
        // server-side but still return an HTTP error. Check whether it
        // actually landed before treating this as a real failure.
        observation = await findJustCreatedObservation(
          jwt,
          user.id,
          trimmedSpeciesGuess,
          attemptStartedAt,
        );
        if (!observation) throw createErr;
      }

      if (photo && observation?.id) {
        await addObservationPhoto(jwt, observation.id, photo);
      }

      Alert.alert('Observation posted', 'Your observation was posted to iNaturalist.', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch (err) {
      console.warn('Failed to post observation', err);
      Alert.alert('Failed to post observation', err.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.label}>What did you see?</Text>
      <TextInput
        style={styles.input}
        placeholder="e.g. Western Fence Lizard"
        value={speciesGuess}
        onChangeText={setSpeciesGuess}
      />

      <Text style={styles.label}>Date observed</Text>
      <TextInput
        style={styles.input}
        placeholder="YYYY-MM-DD"
        value={observedOn}
        onChangeText={setObservedOn}
      />

      <Text style={styles.label}>Description (optional)</Text>
      <TextInput
        style={[styles.input, styles.multiline]}
        placeholder="Notes about this observation"
        value={description}
        onChangeText={setDescription}
        multiline
      />

      <Text style={styles.label}>Location (optional)</Text>
      <TouchableOpacity style={styles.secondaryButton} onPress={useCurrentLocation} disabled={locating}>
        {locating ? (
          <ActivityIndicator />
        ) : (
          <Text style={styles.secondaryButtonText}>
            {location ? 'Update current location' : 'Use current location'}
          </Text>
        )}
      </TouchableOpacity>
      {location ? (
        <Text style={styles.hint}>
          {location.latitude.toFixed(5)}
          {', '}
          {location.longitude.toFixed(5)}
        </Text>
      ) : null}

      <Text style={styles.label}>Photo (optional)</Text>
      <View style={styles.photoRow}>
        <TouchableOpacity style={styles.secondaryButton} onPress={pickPhoto}>
          <Text style={styles.secondaryButtonText}>Choose Photo</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.secondaryButton} onPress={takePhoto}>
          <Text style={styles.secondaryButtonText}>Take Photo</Text>
        </TouchableOpacity>
      </View>
      {photo ? <Image source={{ uri: photo.uri }} style={styles.preview} /> : null}

      <TouchableOpacity
        style={[styles.primaryButton, submitting && styles.disabledButton]}
        onPress={submit}
        disabled={submitting}
      >
        {submitting ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.primaryButtonText}>Post Observation</Text>
        )}
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, paddingBottom: 40 },
  label: {
    fontSize: 14, fontWeight: '600', marginTop: 16, marginBottom: 6, color: '#333',
  },
  input: {
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
  },
  multiline: { minHeight: 80, textAlignVertical: 'top' },
  hint: { marginTop: 6, color: '#666', fontSize: 13 },
  photoRow: { flexDirection: 'row', gap: 10 },
  preview: {
    width: 120, height: 120, borderRadius: 8, marginTop: 12,
  },
  secondaryButton: {
    borderWidth: 1,
    borderColor: '#74ac00',
    borderRadius: 8,
    paddingVertical: 10,
    paddingHorizontal: 14,
    alignItems: 'center',
    marginRight: 10,
    marginTop: 4,
  },
  secondaryButtonText: { color: '#74ac00', fontWeight: '600' },
  primaryButton: {
    backgroundColor: '#74ac00',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 28,
  },
  disabledButton: { opacity: 0.6 },
  primaryButtonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});
