// Backend abstraction interfaces for easy AWS migration
export interface Session {
  id: string;
  name: string;
  created_at: string;
  updated_at: string;
  last_accessed_at: string;
}

export interface SessionData {
  userInput: string;
  propertyType: string;
  photos: File[];
  media: File[];
  generatedDescription: string;
  chatMessages: any[];
  photoAnalyses: any[];
  propertyStory: string;
}

export interface User {
  id: string;
  email: string;
}

export interface DatabaseService {
  // Session operations
  getSessions(): Promise<Session[]>;
  getSession(sessionId: string): Promise<Session | null>;
  createSession(userId: string, name: string): Promise<Session>;
  updateSession(sessionId: string, updates: Partial<Session>): Promise<void>;
  deleteSession(sessionId: string): Promise<void>;

  // Session data operations
  getSessionData(sessionId: string): Promise<SessionData | null>;
  upsertSessionData(sessionId: string, data: SessionData): Promise<void>;
}

export interface AuthService {
  getCurrentUser(): Promise<User | null>;
  signInWithGoogle(): Promise<void>;
  signOut(): Promise<void>;
  onAuthStateChange(callback: (user: User | null) => void): () => void;
}

export interface StorageService {
  uploadFile(path: string, file: File): Promise<string>;
  getPublicUrl(path: string): string;
  deleteFile(path: string): Promise<void>;
}