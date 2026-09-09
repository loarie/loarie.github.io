import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StatusBar } from 'expo-status-bar';
import React from 'react';
import { ActivityIndicator, View } from 'react-native';

import { AuthProvider, useAuth } from './src/context/AuthContext';
import HomeScreen from './src/screens/HomeScreen';
import LoginScreen from './src/screens/LoginScreen';
import NewObservationScreen from './src/screens/NewObservationScreen';
import ObservationDetailScreen from './src/screens/ObservationDetailScreen';
import WelcomeScreen from './src/screens/WelcomeScreen';

const Stack = createNativeStackNavigator();

function RootNavigator() {
  const { status } = useAuth();

  if (status === 'checking') {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  return (
    <Stack.Navigator>
      {status === 'loggedIn' ? (
        <>
          <Stack.Screen name="Home" component={HomeScreen} options={{ title: 'iNaturalist' }} />
          <Stack.Screen
            name="NewObservation"
            component={NewObservationScreen}
            options={{ title: 'New Observation' }}
          />
          <Stack.Screen
            name="ObservationDetail"
            component={ObservationDetailScreen}
            options={{ title: 'Observation' }}
          />
        </>
      ) : (
        <>
          <Stack.Screen name="Welcome" component={WelcomeScreen} options={{ title: 'iNat Example Client' }} />
          <Stack.Screen name="Login" component={LoginScreen} options={{ title: 'Sign in to iNaturalist' }} />
        </>
      )}
    </Stack.Navigator>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <NavigationContainer>
        <RootNavigator />
      </NavigationContainer>
      <StatusBar style="auto" />
    </AuthProvider>
  );
}
