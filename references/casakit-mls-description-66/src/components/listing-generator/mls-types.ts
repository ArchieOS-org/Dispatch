/**
 * MLS Types & Interfaces
 * 
 * Defines the structure for MLS (Multiple Listing Service) data
 * that gets generated alongside property descriptions.
 */

export interface MLSField {
  id: string;
  label: string;
  value: string;
  type: 'text' | 'number' | 'select' | 'boolean';
  category: 'basic' | 'details' | 'features' | 'location';
  options?: string[];
  required?: boolean;
}

export interface MLSFields {
  [key: string]: any;
}

export interface PropertyStoryWithMLS {
  mlsDescription: string;
  storyText: string;
  mlsFields?: MLSField[];
  propertyHighlights?: string[];
  marketingTags?: string[];
}