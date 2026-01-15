// Supabase implementation of backend services
import { supabase } from '@/integrations/supabase/client';
import type { DatabaseService, AuthService, StorageService, Session, SessionData, User } from './interfaces';

export class SupabaseDatabaseService implements DatabaseService {
  async getSessions(): Promise<Session[]> {
    const { data, error } = await supabase
      .from('sessions')
      .select('*')
      .order('last_accessed_at', { ascending: false });

    if (error) throw error;
    return data || [];
  }

  async getSession(sessionId: string): Promise<Session | null> {
    const { data, error } = await supabase
      .from('sessions')
      .select('*')
      .eq('id', sessionId)
      .single();

    if (error) throw error;
    return data;
  }

  async createSession(userId: string, name: string): Promise<Session> {
    const { data, error } = await supabase
      .from('sessions')
      .insert({
        user_id: userId,
        name: name,
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  async updateSession(sessionId: string, updates: Partial<Session>): Promise<void> {
    const { error } = await supabase
      .from('sessions')
      .update(updates)
      .eq('id', sessionId);

    if (error) throw error;
  }

  async deleteSession(sessionId: string): Promise<void> {
    const { error } = await supabase
      .from('sessions')
      .delete()
      .eq('id', sessionId);

    if (error) throw error;
  }

  async getSessionData(sessionId: string): Promise<SessionData | null> {
    const { data, error } = await supabase
      .from('session_data')
      .select('*')
      .eq('session_id', sessionId)
      .single();

    if (error) throw error;

    return {
      userInput: String(data.user_input || ''),
      propertyType: String(data.property_type || ''),
      photos: [], // Files can't be restored from JSON
      media: [], // Files can't be restored from JSON
      generatedDescription: String(data.generated_description || ''),
      chatMessages: data.chat_messages ? JSON.parse(String(data.chat_messages)) : [],
      photoAnalyses: data.photo_analyses ? JSON.parse(String(data.photo_analyses)) : [],
      propertyStory: String(data.property_story || ''),
    };
  }

  async upsertSessionData(sessionId: string, data: SessionData): Promise<void> {
    const { error } = await supabase
      .from('session_data')
      .upsert({
        session_id: sessionId,
        user_input: data.userInput,
        property_type: data.propertyType,
        photos: JSON.stringify(data.photos.map(f => ({ name: f.name, size: f.size, type: f.type }))),
        media: JSON.stringify(data.media.map(f => ({ name: f.name, size: f.size, type: f.type }))),
        generated_description: data.generatedDescription,
        chat_messages: JSON.stringify(data.chatMessages),
        photo_analyses: JSON.stringify(data.photoAnalyses),
        property_story: data.propertyStory,
      });

    if (error) throw error;
  }
}

export class SupabaseAuthService implements AuthService {
  async getCurrentUser(): Promise<User | null> {
    const { data: { user } } = await supabase.auth.getUser();
    return user ? { id: user.id, email: user.email || '' } : null;
  }

  async signInWithGoogle(): Promise<void> {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        scopes: 'openid email profile https://www.googleapis.com/auth/forms.readonly https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/spreadsheets.readonly',
        redirectTo: `${window.location.origin}/`
      }
    });
    
    if (error) throw error;
  }

  async signOut(): Promise<void> {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  }

  onAuthStateChange(callback: (user: User | null) => void): () => void {
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        const user = session?.user ? { id: session.user.id, email: session.user.email || '' } : null;
        callback(user);
      }
    );

    return () => subscription.unsubscribe();
  }
}

export class SupabaseStorageService implements StorageService {
  async uploadFile(path: string, file: File): Promise<string> {
    const { data, error } = await supabase.storage
      .from('files')
      .upload(path, file);

    if (error) throw error;
    return data.path;
  }

  getPublicUrl(path: string): string {
    const { data } = supabase.storage
      .from('files')
      .getPublicUrl(path);

    return data.publicUrl;
  }

  async deleteFile(path: string): Promise<void> {
    const { error } = await supabase.storage
      .from('files')
      .remove([path]);

    if (error) throw error;
  }
}