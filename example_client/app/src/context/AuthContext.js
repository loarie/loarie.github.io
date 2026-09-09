import React, {
  createContext, useCallback, useContext, useEffect, useMemo, useState,
} from 'react';

import { completeLogin, getValidJwt, logout as logoutStorage } from '../api/auth';
import { getCurrentUser } from '../api/inat';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  // status: 'checking' | 'loggedOut' | 'loggedIn'
  const [status, setStatus] = useState('checking');
  const [jwt, setJwt] = useState(null);
  const [user, setUser] = useState(null);

  const restoreSession = useCallback(async () => {
    setStatus('checking');
    try {
      const validJwt = await getValidJwt();
      if (!validJwt) {
        setStatus('loggedOut');
        return;
      }
      const currentUser = await getCurrentUser(validJwt);
      setJwt(validJwt);
      setUser(currentUser);
      setStatus('loggedIn');
    } catch (err) {
      console.warn('Failed to restore iNaturalist session', err);
      await logoutStorage();
      setStatus('loggedOut');
    }
  }, []);

  useEffect(() => {
    restoreSession();
  }, [restoreSession]);

  const login = useCallback(async (authorizationCode) => {
    const newJwt = await completeLogin(authorizationCode);
    const currentUser = await getCurrentUser(newJwt);
    setJwt(newJwt);
    setUser(currentUser);
    setStatus('loggedIn');
  }, []);

  const logout = useCallback(async () => {
    await logoutStorage();
    setJwt(null);
    setUser(null);
    setStatus('loggedOut');
  }, []);

  const value = useMemo(() => ({
    status, jwt, user, login, logout,
  }), [status, jwt, user, login, logout]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within an AuthProvider');
  return ctx;
}
