
/**
 * TYPES: Core TypeScript definitions for the Property Listing Generator
 * 
 * This file contains all the essential type definitions used throughout the application.
 * These types define the structure of data for photos, media files, analysis results,
 * and various configuration options for property listing generation.
 * 
 * Key Types:
 * - PhotoInfo: Individual photo with analysis metadata
 * - MediaInfo: Any media file (photo, document, floorplan) with categorization
 * - PhotoAnalysisDetail: AI analysis results for photos
 * - PropertyType: Supported property categories for targeted descriptions
 * - ModificationType: Available modification styles for generated descriptions
 */

// ============================================================================
// CORE TYPE DEFINITIONS
// ============================================================================

// Media category types - unified with listing generator
export type MediaCategory = 'exterior' | 'interior' | 'kitchen' | 'bathroom' | 'bedroom' | 'livingroom' | 'living' | 'dining' | 'other';
export type MediaType = 'photo' | 'document' | 'floorplan';
export type RoomType = 'kitchen' | 'bathroom' | 'bedroom' | 'livingroom' | 'dining' | 'office' | 'exterior' | 'room';

// Property and modification types
export type PropertyType = 
  | 'luxury' 
  | 'family' 
  | 'investment' 
  | 'starter' 
  | 'vacation'
  | 'commercial'
  | 'land';

export type ModificationType = 
  | 'luxury' 
  | 'emotional' 
  | 'practical' 
  | 'concise' 
  | 'detailed'
  | 'custom';

// Configuration constants
export const MAX_PHOTOS = 50;
export const MAX_MEDIA_FILES = 50;

// ============================================================================
// MEDIA & PHOTO INTERFACES
// ============================================================================

/**
 * PhotoInfo: Individual photo with AI analysis and categorization
 * Used for photo upload, sorting, and analysis display
 */
export interface PhotoInfo {
  id: string;                    // Unique identifier for the photo
  file: File;                   // Original file object
  url: string;                  // Object URL for display
  analysis?: string;            // AI-generated description of the photo
  category: MediaCategory;      // Category classification
  sortOrder?: number;           // User-defined sort order for photo sequence
  roomType?: RoomType;          // Room type classification
  qualityScore?: number;        // AI-assessed image quality (0-10)
  confidence?: number;          // AI confidence level in analysis (0-10)
}

/**
 * MediaInfo: Any uploaded media file with type classification
 * Encompasses photos, documents, and floorplans with unified interface
 */
export interface MediaInfo {
  id: string;                   // Unique identifier for the media
  file: File;                   // Original file object
  url: string;                  // Object URL for display/preview
  type: MediaType;              // Media type classification
  analysis?: string;            // AI analysis results (mainly for photos)
  category: MediaCategory;      // Category classification
  sortOrder?: number;           // User-defined sort order
  roomType?: RoomType;          // Room type classification
  qualityScore?: number;        // AI quality assessment (0-10)
  confidence?: number;          // AI confidence in analysis (0-10)
}

// ============================================================================
// AI ANALYSIS INTERFACES  
// ============================================================================

/**
 * PhotoAnalysisDetail: Detailed AI analysis results for individual photos
 * Contains descriptive analysis and quality metrics
 */
export interface PhotoAnalysisDetail {
  description: string;          // Detailed AI-generated description
  roomType: RoomType;           // Room type classification
  qualityScore: number;        // Image quality score (0-10)
  confidence: number;          // AI confidence level (0-10)
}

/**
 * MediaAnalysisDetail: Extended analysis for all media types
 * Includes media type classification and analysis results
 */
export interface MediaAnalysisDetail extends PhotoAnalysisDetail {
  type: MediaType;              // Media type classification
}
