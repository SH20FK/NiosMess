import { useCallback, useEffect, useMemo, useState } from 'react';

export type Session = {
  token: string;
  username: string;
  name?: string;
};

const SESSION_KEY = 'niosmess_session';

export function loadSession(): Session | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (parsed?.token && parsed?.username) return parsed as Session;
    return null;
  } catch {
    return null;
  }
}

export function saveSession(session: Session) {
  localStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

export function clearSession() {
  localStorage.removeItem(SESSION_KEY);
}

export function useSessionState() {
  const [session, setSessionState] = useState<Session | null>(() => loadSession());

  const setSession = useCallback((next: Session | null) => {
    setSessionState(next);
    if (next) {
      saveSession(next);
    } else {
      clearSession();
    }
  }, []);

  return useMemo(() => ({ session, setSession }), [session, setSession]);
}
