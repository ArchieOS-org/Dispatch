import { createContext, useContext, ReactNode } from 'react';
import { useSessionManager } from './useSessionManager';

type SessionContextType = ReturnType<typeof useSessionManager> | null;

const SessionContext = createContext<SessionContextType>(null);

export const useSessionContext = () => {
  const context = useContext(SessionContext);
  return context;
};

interface SessionProviderProps {
  children: ReactNode;
}

export const SessionProvider = ({ children }: SessionProviderProps) => {
  const sessionManager = useSessionManager();

  return (
    <SessionContext.Provider value={sessionManager}>
      {children}
    </SessionContext.Provider>
  );
};