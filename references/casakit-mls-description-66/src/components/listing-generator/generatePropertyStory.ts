/**
 * Property Story Generator
 * 
 * Uses Google Gemini to create comprehensive property descriptions including
 * MLS-formatted content, marketing copy, and structured data fields.
 */

import { GoogleGenerativeAI } from "@google/generative-ai";
import type { PropertyType } from "./types";
import type { PropertyStoryWithMLS } from "./mls-types";
import type { EnhancedMLSFields, PropertyStoryWithEnhancedMLS } from "./enhanced-mls-types";

// Photo analysis interface (simplified for this function)
export interface PhotoAnalysis {
  description: string;
  category: string;
  features: string[];
  storyText: string;
  roomType: string;
  confidence: number;
}

// Get Gemini API key
const getGeminiKey = async () => {
  try {
    const response = await fetch('/api/get-gemini-key');
    if (!response.ok) throw new Error('Failed to get API key');
    const data = await response.json();
    return data.key;
  } catch (error) {
    console.error('Failed to get Gemini key:', error);
    throw new Error('API key not available');
  }
};

export const generatePropertyStory = async (
  input: string,
  propertyType?: PropertyType,
  photoAnalyses: PhotoAnalysis[] = []
): Promise<PropertyStoryWithEnhancedMLS> => {
  const apiKey = await getGeminiKey();
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-pro" });

  // Build photo analysis context
  const photoContext = photoAnalyses.length > 0 
    ? `\n\nPhoto Analysis:\n${photoAnalyses.map((analysis, index) => 
        `Photo ${index + 1} (${analysis.category}): ${analysis.description}\nFeatures: ${analysis.features.join(', ')}\nStory: ${analysis.storyText}`
      ).join('\n\n')}`
    : '';

  const typeContext = propertyType ? `Property Type: ${propertyType}\n` : '';

  const prompt = `Create a comprehensive property story and MLS listing based on the following information:

${typeContext}Property Information:
${input}${photoContext}

Please generate a JSON response with the following structure:
{
  "mlsDescription": "Professional MLS description (400-500 words)",
  "storyText": "Compelling walkthrough narrative (300-400 words)",
  "mlsFields": [
    {
      "id": "unique_id",
      "label": "Field Label",
      "value": "Field Value",
      "type": "text|number|select|boolean",
      "category": "basic|details|features|location",
      "options": ["if", "select", "type"],
      "required": true
    }
  ],
  "propertyHighlights": ["highlight1", "highlight2", "highlight3"],
  "marketingTags": ["tag1", "tag2", "tag3"]
}

Requirements:
- MLS Description: Professional, keyword-rich, under 500 words
- Story Text: Engaging walkthrough that helps buyers envision living there
- MLS Fields: Extract relevant data like bedrooms, bathrooms, square footage, lot size, year built, etc.
- Highlights: 5-7 key selling points
- Marketing Tags: 5-8 relevant tags for marketing

Make sure all text is compelling, accurate to the provided information, and optimized for real estate marketing.`;

  try {
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    // Try to parse JSON response
    try {
      const parsed = JSON.parse(text);
      const mlsDescription = parsed.mlsDescription || '';
      
      // Create enhanced MLS fields with synced client remarks
      const enhancedMLSFields: EnhancedMLSFields = {
        location: {},
        amounts: {},
        exterior: {},
        waterfront: {},
        interior: {},
        comments: {
          remarksForClients: mlsDescription // Auto-sync with MLS description
        },
        other: {}
      };
      
      return {
        mlsDescription,
        storyText: parsed.storyText || '',
        mlsFields: enhancedMLSFields,
        propertyHighlights: parsed.propertyHighlights || [],
        marketingTags: parsed.marketingTags || []
      };
    } catch (parseError) {
      console.warn('Failed to parse JSON response, using fallback approach');
      
      const mlsDescription = text.trim();
      
      // Fallback: create basic enhanced MLS fields with synced client remarks
      const enhancedMLSFields: EnhancedMLSFields = {
        location: {},
        amounts: {},
        exterior: {},
        waterfront: {},
        interior: {},
        comments: {
          remarksForClients: mlsDescription // Auto-sync with MLS description
        },
        other: {}
      };
      
      return {
        mlsDescription,
        storyText: mlsDescription,
        mlsFields: enhancedMLSFields,
        propertyHighlights: [],
        marketingTags: []
      };
    }
  } catch (error) {
    console.error('Error generating property story:', error);
    throw new Error('Failed to generate property story. Please check your input and try again.');
  }
};