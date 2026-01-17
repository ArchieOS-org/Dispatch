
/**
 * Core Types & Interfaces for Property Listing Generator
 * 
 * Defines data structures for media handling, AI analysis results,
 * and configuration options for the property listing generation system.
 */

// Base type for file uploads
export interface MediaFile extends File {
  // Extended File interface for media handling
}

// Media category types - updated to match existing usage
export type MediaCategory = 'exterior' | 'interior' | 'kitchen' | 'bathroom' | 'bedroom' | 'livingroom' | 'dining' | 'living' | 'other';
export type MediaType = 'photo' | 'document' | 'floorplan';
export type RoomType = 'kitchen' | 'bathroom' | 'bedroom' | 'livingroom' | 'dining' | 'office' | 'exterior' | 'room';

// Media information interface
export interface PhotoInfo {
  id: string;
  file: File;
  url: string;
  category: MediaCategory;
  analysis?: string;
  roomType?: RoomType;
  confidence?: number;
  sortOrder?: number;
}

// Enhanced media info interface for all media types
export interface MediaInfo {
  id: string;
  file: File;
  url: string;
  type: MediaType;
  category: MediaCategory;
  analysis?: string;
  roomType?: RoomType;
  confidence?: number;
  sortOrder?: number;
}

// Analysis interfaces
export interface PhotoAnalysisDetail {
  description: string;
  category: MediaCategory;
  features: string[];
  storyText: string;
  roomType: RoomType;
  confidence: number;
}

export interface MediaAnalysisDetail extends PhotoAnalysisDetail {
  type: MediaType;
}

// Property and modification types
export type PropertyType = 
  | 'luxury' 
  | 'family' 
  | 'investment' 
  | 'starter' 
  | 'vacation'
  | 'commercial';

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
