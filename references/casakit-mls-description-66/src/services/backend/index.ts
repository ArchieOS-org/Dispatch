// Backend service factory - easily switch between Supabase and AWS
import { SupabaseDatabaseService, SupabaseAuthService, SupabaseStorageService } from './supabase';
import type { DatabaseService, AuthService, StorageService } from './interfaces';

// Backend provider configuration
type BackendProvider = 'supabase' | 'aws';
const BACKEND_PROVIDER: BackendProvider = 'supabase'; // Could be 'aws' in the future

// Service factory functions
export function createDatabaseService(): DatabaseService {
  switch (BACKEND_PROVIDER) {
    case 'supabase':
      return new SupabaseDatabaseService();
    case 'aws':
      // TODO: Implement AWS service
      throw new Error('AWS database service not implemented yet');
    default:
      throw new Error(`Unknown backend provider: ${BACKEND_PROVIDER}`);
  }
}

export function createAuthService(): AuthService {
  switch (BACKEND_PROVIDER) {
    case 'supabase':
      return new SupabaseAuthService();
    case 'aws':
      // TODO: Implement AWS service
      throw new Error('AWS auth service not implemented yet');
    default:
      throw new Error(`Unknown backend provider: ${BACKEND_PROVIDER}`);
  }
}

export function createStorageService(): StorageService {
  switch (BACKEND_PROVIDER) {
    case 'supabase':
      return new SupabaseStorageService();
    case 'aws':
      // TODO: Implement AWS service
      throw new Error('AWS storage service not implemented yet');
    default:
      throw new Error(`Unknown backend provider: ${BACKEND_PROVIDER}`);
  }
}

// Re-export types for convenience
export type { DatabaseService, AuthService, StorageService, Session, SessionData, User } from './interfaces';