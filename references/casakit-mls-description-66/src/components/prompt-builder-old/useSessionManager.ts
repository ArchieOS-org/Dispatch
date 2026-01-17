import { useState, useEffect, useCallback } from 'react';
import { useToast } from '@/hooks/use-toast';
import { debounce } from 'lodash';
import { createDatabaseService } from '@/services/backend';
import type { Session, SessionData } from '@/services/backend';

export const useSessionManager = () => {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [currentSessionId, setCurrentSessionId] = useState<string | null>(null);
  const [currentSessionData, setCurrentSessionData] = useState<SessionData>({
    userInput: '',
    propertyType: '',
    photos: [],
    media: [],
    generatedDescription: '',
    chatMessages: [],
    photoAnalyses: [],
    propertyStory: '',
  });
  const [isLoading, setIsLoading] = useState(false);
  const { toast } = useToast();
  const databaseService = createDatabaseService();

  // Auto-save session data with debouncing
  const debouncedSave = useCallback(
    debounce(async (sessionId: string, data: SessionData) => {
      if (!sessionId) return;
      
      try {
        await databaseService.upsertSessionData(sessionId, data);
      } catch (error) {
        console.error('Failed to auto-save session:', error);
      }
    }, 1000),
    [databaseService]
  );

  // Generate smart session name from user input
  const generateSessionName = (userInput: string): string => {
    if (!userInput) return 'New Session';
    
    const words = userInput.trim().split(' ').slice(0, 4);
    const name = words.join(' ');
    return name.length > 30 ? name.substring(0, 30) + '...' : name;
  };

  // Load all sessions for current user
  const loadSessions = useCallback(async () => {
    try {
      const sessions = await databaseService.getSessions();
      setSessions(sessions);
    } catch (error) {
      console.error('Failed to load sessions:', error);
      toast({
        title: "Failed to load sessions",
        description: "Please try again.",
        variant: "destructive",
      });
    }
  }, [databaseService, toast]);

  // Create new session
  const createSession = useCallback(async (initialData?: Partial<SessionData>) => {
    setIsLoading(true);
    
    try {
      const authService = await import('@/services/backend').then(m => m.createAuthService());
      const user = await authService.getCurrentUser();
      if (!user) throw new Error('User not authenticated');

      const sessionName = initialData?.userInput 
        ? generateSessionName(initialData.userInput)
        : 'New Session';

      const session = await databaseService.createSession(user.id, sessionName);

      // Create session data
      const newSessionData = {
        userInput: initialData?.userInput || '',
        propertyType: initialData?.propertyType || '',
        photos: initialData?.photos || [],
        media: initialData?.media || [],
        generatedDescription: initialData?.generatedDescription || '',
        chatMessages: initialData?.chatMessages || [],
        photoAnalyses: initialData?.photoAnalyses || [],
        propertyStory: initialData?.propertyStory || '',
      };

      await databaseService.upsertSessionData(session.id, newSessionData);

      setCurrentSessionId(session.id);
      setCurrentSessionData(newSessionData);
      await loadSessions();

      toast({
        title: "New session created",
        description: sessionName,
      });

      return session.id;
    } catch (error) {
      console.error('Failed to create session:', error);
      toast({
        title: "Failed to create session",
        description: "Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  }, [databaseService, loadSessions, toast]);

  // Load session data
  const loadSession = useCallback(async (sessionId: string) => {
    setIsLoading(true);
    
    try {
      const sessionData = await databaseService.getSessionData(sessionId);
      
      if (sessionData) {
        setCurrentSessionId(sessionId);
        setCurrentSessionData(sessionData);

        // Update last accessed time
        await databaseService.updateSession(sessionId, { 
          last_accessed_at: new Date().toISOString() 
        });

        await loadSessions();
        return sessionData;
      }
      return null;
    } catch (error) {
      console.error('Failed to load session:', error);
      toast({
        title: "Failed to load session",
        description: "Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  }, [databaseService, loadSessions, toast]);

  // Update session data
  const updateSessionData = useCallback((newData: Partial<SessionData>) => {
    const updatedData = { ...currentSessionData, ...newData };
    setCurrentSessionData(updatedData);
    
    if (currentSessionId) {
      debouncedSave(currentSessionId, updatedData);
      
      // Update session name if user input changed
      if (newData.userInput && newData.userInput !== currentSessionData.userInput) {
        const newName = generateSessionName(newData.userInput);
        databaseService.updateSession(currentSessionId, { name: newName })
          .then(() => loadSessions());
      }
    }
  }, [currentSessionData, currentSessionId, debouncedSave, loadSessions]);

  // Delete session
  const deleteSession = useCallback(async (sessionId: string) => {
    try {
      await databaseService.deleteSession(sessionId);

      if (currentSessionId === sessionId) {
        setCurrentSessionId(null);
        setCurrentSessionData({
          userInput: '',
          propertyType: '',
          photos: [],
          media: [],
          generatedDescription: '',
          chatMessages: [],
          photoAnalyses: [],
          propertyStory: '',
        });
      }

      await loadSessions();
      toast({
        title: "Session deleted",
      });
    } catch (error) {
      console.error('Failed to delete session:', error);
      toast({
        title: "Failed to delete session",
        description: "Please try again.",
        variant: "destructive",
      });
    }
  }, [databaseService, currentSessionId, loadSessions, toast]);

  // Initialize sessions on mount
  useEffect(() => {
    loadSessions();
  }, [loadSessions]);

  return {
    sessions,
    currentSessionId,
    currentSessionData,
    isLoading,
    createSession,
    loadSession,
    updateSessionData,
    deleteSession,
    loadSessions,
  };
};