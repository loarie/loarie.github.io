import { useFocusEffect } from '@react-navigation/native';
import React, {
  useCallback, useRef, useState,
} from 'react';
import {
  ActivityIndicator,
  FlatList,
  Image,
  RefreshControl,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

import { listRecentObservations, observationDisplayName } from '../api/inat';
import { useAuth } from '../context/AuthContext';

const GRID_COLUMNS = 3;

function ObservationTile({ observation, onPress }) {
  const photoUrl = observation.photos?.[0]?.url;
  return (
    <TouchableOpacity style={styles.tile} onPress={onPress}>
      {photoUrl ? (
        <Image source={{ uri: photoUrl }} style={styles.tileImage} />
      ) : (
        <View style={[styles.tileImage, styles.tilePlaceholder]}>
          <Text style={styles.tilePlaceholderText} numberOfLines={3}>
            {observationDisplayName(observation)}
          </Text>
        </View>
      )}
    </TouchableOpacity>
  );
}

export default function HomeScreen({ navigation, route }) {
  const { jwt, user, logout } = useAuth();
  const [observations, setObservations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  // The observation list is Elasticsearch-backed and can briefly still
  // return a just-deleted record, so track deletions locally and always
  // filter them out rather than trusting the server to be caught up yet.
  const deletedIdsRef = useRef(new Set());

  const loadObservations = useCallback(async ({ silent = false } = {}) => {
    if (!user?.id) return;
    if (!silent) setLoading(true);
    try {
      const results = await listRecentObservations(jwt, user.id, 30);
      setObservations(results.filter((o) => !deletedIdsRef.current.has(o.id)));
    } catch (err) {
      console.warn('Failed to load recent observations', err);
    } finally {
      if (!silent) setLoading(false);
    }
  }, [jwt, user]);

  useFocusEffect(
    useCallback(() => {
      const deletedId = route.params?.deletedObservationId;
      if (deletedId) {
        deletedIdsRef.current.add(deletedId);
        setObservations((prev) => prev.filter((o) => o.id !== deletedId));
        navigation.setParams({ deletedObservationId: undefined });
      }
      loadObservations();
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [loadObservations, navigation, route.params?.deletedObservationId]),
  );

  const onRefresh = async () => {
    setRefreshing(true);
    await loadObservations({ silent: true });
    setRefreshing(false);
  };

  return (
    <FlatList
      style={styles.container}
      data={observations}
      keyExtractor={(item) => String(item.id)}
      numColumns={GRID_COLUMNS}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      ListHeaderComponent={(
        <View>
          <View style={styles.profile}>
            {user?.icon_url ? (
              <Image source={{ uri: user.icon_url }} style={styles.avatar} />
            ) : null}
            <Text style={styles.name}>{user?.name || user?.login}</Text>
            <Text style={styles.login}>@{user?.login}</Text>
            <Text style={styles.stat}>{user?.observations_count ?? 0} observations</Text>
          </View>

          <TouchableOpacity
            style={styles.primaryButton}
            onPress={() => navigation.navigate('NewObservation')}
          >
            <Text style={styles.primaryButtonText}>New Observation</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.logoutButton} onPress={logout}>
            <Text style={styles.logoutButtonText}>Log Out</Text>
          </TouchableOpacity>

          <Text style={styles.sectionTitle}>Recent Observations</Text>
          {loading ? <ActivityIndicator style={styles.loading} /> : null}
        </View>
      )}
      ListEmptyComponent={!loading ? (
        <Text style={styles.emptyText}>No observations yet.</Text>
      ) : null}
      renderItem={({ item }) => (
        <ObservationTile
          observation={item}
          onPress={() => navigation.navigate('ObservationDetail', { observationId: item.id })}
        />
      )}
      contentContainerStyle={styles.listContent}
    />
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  listContent: { padding: 16, paddingBottom: 40 },
  profile: { alignItems: 'center', marginBottom: 24 },
  avatar: {
    width: 88, height: 88, borderRadius: 44, marginBottom: 12,
  },
  name: { fontSize: 20, fontWeight: '600' },
  login: { fontSize: 14, color: '#666', marginTop: 2 },
  stat: { fontSize: 14, color: '#666', marginTop: 8 },
  primaryButton: {
    backgroundColor: '#74ac00',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 12,
  },
  primaryButtonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  logoutButton: { paddingVertical: 10, alignItems: 'center', marginBottom: 8 },
  logoutButtonText: { color: '#b3261e', fontSize: 15 },
  sectionTitle: {
    fontSize: 16, fontWeight: '600', marginTop: 16, marginBottom: 12,
  },
  loading: { marginBottom: 12 },
  emptyText: { color: '#666', textAlign: 'center', marginTop: 20 },
  tile: {
    flex: 1 / GRID_COLUMNS,
    aspectRatio: 1,
    padding: 2,
  },
  tileImage: {
    flex: 1,
    borderRadius: 4,
    backgroundColor: '#eee',
  },
  tilePlaceholder: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: 6,
  },
  tilePlaceholderText: {
    fontSize: 11, color: '#888', textAlign: 'center',
  },
});
