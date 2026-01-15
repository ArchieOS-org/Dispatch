
/**
 * Session Manager Hook
 * 
 * Manages user sessions for the property listing generator,
 * including creating, loading, updating, and deleting sessions.
 * Handles auto-saving session data with debouncing.
 */

import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';
import { debounce } from 'lodash';
import { demoSessions, demoSessionData } from './demoData';
import type { Session as BackendSession } from '@/services/backend/interfaces';

export interface SessionData {
  userInput: string;
  propertyType: string;
  photos: File[];
  media: File[];
  generatedDescription: string;
  photoAnalyses: any[];
  propertyStory: string;
}

export interface Session {
  id: string;
  name: string;
  created_at: string;
  updated_at: string;
  last_accessed_at: string;
  user_id: string;
}

export const useSessionManager = () => {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [currentSessionId, setCurrentSessionId] = useState<string | null>('temp-new-session');
  const [currentSessionData, setCurrentSessionData] = useState<SessionData | null>({
    userInput: '',
    propertyType: '',
    photos: [],
    media: [],
    generatedDescription: '',
    photoAnalyses: [],
    propertyStory: '',
  });
  const [isLoading, setIsLoading] = useState(false);
  const { toast } = useToast();

  // Create default temporary session
  const createDefaultSession = (): Session => ({
    id: 'temp-new-session',
    name: 'New Session',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    last_accessed_at: new Date().toISOString(),
    user_id: 'temp'
  });

  // Debounced save function to prevent excessive database writes
  const debouncedSave = useCallback(
    debounce(async (sessionId: string, data: SessionData) => {
      try {
        await supabase
          .from('session_data')
          .upsert({ 
            session_id: sessionId,
            user_input: data.userInput,
            property_type: data.propertyType,
            photos: JSON.stringify(data.photos.map(f => ({ name: f.name, size: f.size, type: f.type }))),
            media: JSON.stringify(data.media.map(f => ({ name: f.name, size: f.size, type: f.type }))),
            generated_description: data.generatedDescription,
            photo_analyses: JSON.stringify(data.photoAnalyses),
            property_story: data.propertyStory,
            updated_at: new Date().toISOString()
          });
      } catch (error) {
        console.error('Failed to save session:', error);
      }
    }, 1000),
    []
  );

  // Generate a session name from user input
  const generateSessionName = (userInput: string): string => {
    if (!userInput.trim()) return `Session ${new Date().toLocaleDateString()}`;
    
    const words = userInput.trim().split(' ').slice(0, 4);
    return words.join(' ') + (userInput.split(' ').length > 4 ? '...' : '');
  };

  // Load all sessions for the current user
  const loadSessions = useCallback(async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('sessions')
        .select('*')
        .order('updated_at', { ascending: false });

      if (error) throw error;
      
      // Add demo sessions to the list for UI testing (convert to local Session format)
      const convertedDemoSessions: Session[] = demoSessions.map(demo => ({
        ...demo,
        user_id: 'demo-user'
      }));
      
      // Always include the default "New Session" at the top
      const defaultSession = createDefaultSession();
      const allSessions = [defaultSession, ...convertedDemoSessions, ...(data || [])];
      setSessions(allSessions);

      // If no current session is selected or it's the temp session, keep the temp session selected
      if (!currentSessionId || currentSessionId === 'temp-new-session') {
        setCurrentSessionId('temp-new-session');
      }
    } catch (error) {
      console.error('Failed to load sessions:', error);
      toast({
        title: "Error",
        description: "Failed to load sessions",
        variant: "destructive"
      });
      
      // If loading fails, at least show demo sessions and default session
      const convertedDemoSessions: Session[] = demoSessions.map(demo => ({
        ...demo,
        user_id: 'demo-user'
      }));
      const defaultSession = createDefaultSession();
      setSessions([defaultSession, ...convertedDemoSessions]);
    } finally {
      setIsLoading(false);
    }
  }, [toast, currentSessionId]);

  // Create a new session
  const createSession = useCallback(async (initialData?: Partial<SessionData>): Promise<string | null> => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('User not authenticated');

      const sessionData: SessionData = {
        userInput: '',
        propertyType: '',
        photos: [],
        media: [],
        generatedDescription: '',
        photoAnalyses: [],
        propertyStory: '',
        ...initialData
      };

      const sessionName = generateSessionName(sessionData.userInput);

      const { data, error } = await supabase
        .from('sessions')
        .insert({
          user_id: user.id,
          name: sessionName
        })
        .select()
        .single();

      if (error) throw error;

      const newSession = data;
      setSessions(prev => [newSession, ...prev]);
      setCurrentSessionId(newSession.id);
      setCurrentSessionData(sessionData);

      // Save initial session data
      await supabase
        .from('session_data')
        .insert({
          session_id: newSession.id,
          user_input: sessionData.userInput,
          property_type: sessionData.propertyType,
          photos: JSON.stringify([]),
          media: JSON.stringify([]),
          generated_description: sessionData.generatedDescription,
          photo_analyses: JSON.stringify(sessionData.photoAnalyses),
          property_story: sessionData.propertyStory
        });

      return newSession.id;
    } catch (error) {
      console.error('Failed to create session:', error);
      toast({
        title: "Error",
        description: "Failed to create session",
        variant: "destructive"
      });
      return null;
    }
  }, [toast]);

  // Load a specific session
  const loadSession = useCallback(async (sessionId: string): Promise<SessionData | null> => {
    try {
      // Handle temporary new session
      if (sessionId === 'temp-new-session') {
        const emptyData: SessionData = {
          userInput: '',
          propertyType: '',
          photos: [],
          media: [],
          generatedDescription: '',
          photoAnalyses: [],
          propertyStory: '',
        };
        setCurrentSessionId(sessionId);
        setCurrentSessionData(emptyData);
        return emptyData;
      }

      // Check if this is a demo session
      if (sessionId.startsWith('demo-')) {
        const sessionData = demoSessionData[sessionId] || null;
        setCurrentSessionId(sessionId);
        setCurrentSessionData(sessionData);
        return sessionData;
      }

      // Get session data for real sessions
      const { data: sessionData, error: dataError } = await supabase
        .from('session_data')
        .select('*')
        .eq('session_id', sessionId)
        .single();

      if (dataError) throw dataError;

      const loadedData: SessionData = {
        userInput: sessionData.user_input || '',
        propertyType: sessionData.property_type || '',
        photos: [], // Files can't be restored from JSON
        media: [], // Files can't be restored from JSON
        generatedDescription: sessionData.generated_description || '',
        photoAnalyses: sessionData.photo_analyses ? JSON.parse(String(sessionData.photo_analyses)) : [],
        propertyStory: sessionData.property_story || ''
      };

      setCurrentSessionId(sessionId);
      setCurrentSessionData(loadedData);

      // Update last accessed time
      await supabase
        .from('sessions')
        .update({ last_accessed_at: new Date().toISOString() })
        .eq('id', sessionId);

      return loadedData;
    } catch (error) {
      console.error('Failed to load session:', error);
      toast({
        title: "Error",
        description: "Failed to load session",
        variant: "destructive"
      });
      return null;
    }
  }, [toast]);

  // Update current session data
  const updateSessionData = useCallback(async (data: Partial<SessionData>) => {
    if (!currentSessionId) return;

    // Don't allow editing demo sessions
    if (currentSessionId.startsWith('demo-')) {
      toast({
        title: "Demo Session",
        description: "Demo sessions cannot be modified. Create a new session to save your changes.",
        variant: "default",
      });
      return;
    }

    const updatedData = { ...currentSessionData, ...data } as SessionData;
    setCurrentSessionData(updatedData);

    // If this is the temporary session and user is adding content, convert to real session
    if (currentSessionId === 'temp-new-session' && (data.userInput || data.generatedDescription)) {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
          const sessionName = generateSessionName(updatedData.userInput);
          
          const { data: newSession, error } = await supabase
            .from('sessions')
            .insert({
              user_id: user.id,
              name: sessionName
            })
            .select()
            .single();

          if (!error && newSession) {
            // Save session data
            await supabase
              .from('session_data')
              .insert({
                session_id: newSession.id,
                user_input: updatedData.userInput,
                property_type: updatedData.propertyType,
                photos: JSON.stringify([]),
                media: JSON.stringify([]),
                generated_description: updatedData.generatedDescription,
                photo_analyses: JSON.stringify(updatedData.photoAnalyses),
                property_story: updatedData.propertyStory
              });

            // Update current session to the new real session
            setCurrentSessionId(newSession.id);
            
            // Update sessions list - replace temp session with real session
            setSessions(prev => [
              newSession,
              ...prev.filter(s => s.id !== 'temp-new-session')
            ]);

            // Create a new temp session for future use
            const defaultSession = createDefaultSession();
            setSessions(prev => [defaultSession, ...prev]);

            return;
          }
        }
      } catch (error) {
        console.error('Failed to convert temp session to real session:', error);
      }
    }

    // Update session name if user input changed (for real sessions)
    if (currentSessionId !== 'temp-new-session') {
      const newName = generateSessionName(updatedData.userInput);
      setSessions(prev => prev.map(session => 
        session.id === currentSessionId 
          ? { ...session, name: newName }
          : session
      ));

      // Debounced save to database
      debouncedSave(currentSessionId, updatedData);
    } else {
      // For temp session, just update the name in the UI
      const newName = generateSessionName(updatedData.userInput);
      setSessions(prev => prev.map(session => 
        session.id === currentSessionId 
          ? { ...session, name: newName || 'New Session' }
          : session
      ));
    }
  }, [currentSessionId, currentSessionData, debouncedSave, toast]);

  // Delete a session
  const deleteSession = useCallback(async (sessionId: string) => {
    // Don't allow deleting demo sessions or temp session
    if (sessionId.startsWith('demo-') || sessionId === 'temp-new-session') {
      toast({
        title: sessionId === 'temp-new-session' ? "New Session" : "Demo Session",
        description: sessionId === 'temp-new-session' 
          ? "The default new session cannot be deleted." 
          : "Demo sessions cannot be deleted.",
        variant: "default",
      });
      return;
    }

    try {
      const { error } = await supabase
        .from('sessions')
        .delete()
        .eq('id', sessionId);

      if (error) throw error;

      setSessions(prev => prev.filter(s => s.id !== sessionId));
      
      if (currentSessionId === sessionId) {
        setCurrentSessionId(null);
        setCurrentSessionData(null);
      }

      toast({
        title: "Session Deleted",
        description: "Session has been removed"
      });
    } catch (error) {
      console.error('Failed to delete session:', error);
      toast({
        title: "Error",
        description: "Failed to delete session",
        variant: "destructive"
      });
    }
  }, [currentSessionId, toast]);

  // Load sessions on mount
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
    refreshSessions: loadSessions
  };
};
