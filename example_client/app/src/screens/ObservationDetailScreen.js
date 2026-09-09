import { useNavigation, useRoute } from '@react-navigation/native';
import React, {
  useCallback, useEffect, useLayoutEffect, useState,
} from 'react';
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

import {
  deleteObservation,
  getObservation,
  observationDisplayName,
  retryOnPhantomServerError,
  updateObservation,
} from '../api/inat';
import { useAuth } from '../context/AuthContext';

// iNat photo `url` fields default to the small "square" thumbnail size.
// This is the standard trick for getting a bigger version from the same
// underlying file without an extra request.
function mediumPhotoUrl(url) {
  return url ? url.replace('square', 'medium') : url;
}

export default function ObservationDetailScreen() {
  const navigation = useNavigation();
  const route = useRoute();
  const { observationId } = route.params;
  const { jwt } = useAuth();

  const [observation, setObservation] = useState(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const [speciesGuess, setSpeciesGuess] = useState('');
  const [description, setDescription] = useState('');
  const [observedOn, setObservedOn] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const result = await retryOnPhantomServerError(() => getObservation(jwt, observationId));
      setObservation(result);
    } catch (err) {
      console.warn('Failed to load observation', err);
      Alert.alert('Failed to load observation', err.message);
    } finally {
      setLoading(false);
    }
  }, [jwt, observationId]);

  useEffect(() => {
    load();
  }, [load]);

  const startEditing = () => {
    setSpeciesGuess(observation.species_guess || '');
    setDescription(observation.description || '');
    setObservedOn(observation.observed_on_string || observation.observed_on || '');
    setEditing(true);
  };

  useLayoutEffect(() => {
    navigation.setOptions({
      headerRight: !editing && observation ? () => (
        <TouchableOpacity onPress={startEditing} style={styles.headerButton}>
          <Text style={styles.headerButtonText}>Edit</Text>
        </TouchableOpacity>
      ) : undefined,
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [navigation, editing, observation]);

  const cancelEditing = () => setEditing(false);

  const save = async () => {
    setSaving(true);
    try {
      const updated = await updateObservation(jwt, observationId, {
        species_guess: speciesGuess.trim(),
        description: description.trim(),
        observed_on_string: observedOn.trim(),
      });
      setObservation(updated);
      setEditing(false);
    } catch (err) {
      console.warn('Failed to save observation', err);
      Alert.alert('Failed to save changes', err.message);
    } finally {
      setSaving(false);
    }
  };

  const performDelete = async () => {
    setDeleting(true);
    try {
      await deleteObservation(jwt, observationId);
      // Pass the deleted id back so Home can filter it out immediately,
      // rather than relying on its (Elasticsearch-backed, briefly stale)
      // refetch to reflect the deletion right away.
      navigation.navigate('Home', { deletedObservationId: observationId });
    } catch (err) {
      console.warn('Failed to delete observation', err);
      Alert.alert('Failed to delete observation', err.message);
      setDeleting(false);
    }
  };

  const confirmDelete = () => {
    Alert.alert(
      'Delete this observation?',
      'This cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Delete', style: 'destructive', onPress: performDelete },
      ],
    );
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  if (!observation) {
    return (
      <View style={styles.center}>
        <Text>Observation not found.</Text>
      </View>
    );
  }

  const photoUrl = mediumPhotoUrl(observation.photos?.[0]?.url);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      {photoUrl ? <Image source={{ uri: photoUrl }} style={styles.photo} /> : null}

      {editing ? (
        <View>
          <Text style={styles.label}>What did you see?</Text>
          <TextInput
            style={styles.input}
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

          <Text style={styles.label}>Description</Text>
          <TextInput
            style={[styles.input, styles.multiline]}
            value={description}
            onChangeText={setDescription}
            multiline
          />

          <View style={styles.editActions}>
            <TouchableOpacity
              style={styles.secondaryButton}
              onPress={cancelEditing}
              disabled={saving}
            >
              <Text style={styles.secondaryButtonText}>Cancel</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.primaryButton, saving && styles.disabledButton]}
              onPress={save}
              disabled={saving}
            >
              {saving ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.primaryButtonText}>Save</Text>
              )}
            </TouchableOpacity>
          </View>

          <TouchableOpacity
            style={[styles.deleteButton, deleting && styles.disabledButton]}
            onPress={confirmDelete}
            disabled={saving || deleting}
          >
            {deleting ? (
              <ActivityIndicator color="#b3261e" />
            ) : (
              <Text style={styles.deleteButtonText}>Delete Observation</Text>
            )}
          </TouchableOpacity>
        </View>
      ) : (
        <View>
          <Text style={styles.title}>{observationDisplayName(observation)}</Text>
          <Text style={styles.date}>
            {observation.observed_on_string || observation.observed_on}
          </Text>
          {observation.place_guess ? (
            <Text style={styles.place}>{observation.place_guess}</Text>
          ) : null}
          {observation.description ? (
            <Text style={styles.description}>{observation.description}</Text>
          ) : null}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, paddingBottom: 40 },
  center: {
    flex: 1, alignItems: 'center', justifyContent: 'center',
  },
  photo: {
    width: '100%', height: 260, borderRadius: 8, marginBottom: 20, backgroundColor: '#eee',
  },
  title: { fontSize: 22, fontWeight: '700' },
  date: { fontSize: 14, color: '#666', marginTop: 6 },
  place: { fontSize: 14, color: '#666', marginTop: 4 },
  description: { fontSize: 15, color: '#333', marginTop: 16, lineHeight: 21 },
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
  editActions: {
    flexDirection: 'row', gap: 10, marginTop: 28,
  },
  primaryButton: {
    flex: 1,
    backgroundColor: '#74ac00',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
  },
  disabledButton: { opacity: 0.6 },
  primaryButtonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  secondaryButton: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#74ac00',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
  },
  secondaryButtonText: { color: '#74ac00', fontSize: 16, fontWeight: '600' },
  deleteButton: {
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 20,
  },
  deleteButtonText: { color: '#b3261e', fontSize: 15, fontWeight: '600' },
  headerButton: { paddingHorizontal: 8, paddingVertical: 4 },
  headerButtonText: { color: '#74ac00', fontSize: 16, fontWeight: '600' },
});
