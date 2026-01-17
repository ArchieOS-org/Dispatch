
/**
 * Gemini AI Service
 * 
 * Handles AI-powered photo analysis and property description generation
 * using Google's Gemini Pro Vision and Pro models.
 */

import { GoogleGenerativeAI } from "@google/generative-ai";
import type { PropertyType, PhotoAnalysisDetail, MediaCategory, RoomType } from "./types";

// Initialize Gemini
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

let genAI: GoogleGenerativeAI | null = null;

const initializeGemini = async () => {
  if (!genAI) {
    const apiKey = await getGeminiKey();
    genAI = new GoogleGenerativeAI(apiKey);
  }
  return genAI;
};

// Photo analysis interface
export interface PhotoAnalysis {
  description: string;
  category: MediaCategory;
  features: string[];
  storyText: string;
  roomType: RoomType;
  confidence: number;
}

// Property story interface
export interface PropertyStory {
  walkthrough: string;
  mlsDescription: string;
  highlights: string[];
}

// Convert file to base64 for Gemini
const fileToGenerativePart = async (file: File) => {
  return new Promise<{ inlineData: { data: string; mimeType: string } }>((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const base64String = (reader.result as string).split(',')[1];
      resolve({
        inlineData: {
          data: base64String,
          mimeType: file.type,
        },
      });
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
};

// Analyze photos using Gemini Pro Vision
export const analyzePhotos = async (
  photos: File[],
  onProgress?: (current: number, total: number, stage: string) => void
): Promise<PhotoAnalysis[]> => {
  const gemini = await initializeGemini();
  const model = gemini!.getGenerativeModel({ model: "gemini-1.5-pro" });

  const results: PhotoAnalysis[] = [];

  for (let i = 0; i < photos.length; i++) {
    const photo = photos[i];
    
    if (onProgress) {
      onProgress(i + 1, photos.length, `Analyzing photo ${i + 1} of ${photos.length}`);
    }

    try {
      const imagePart = await fileToGenerativePart(photo);
      
      const prompt = `Analyze this real estate photo and provide a JSON response with the following structure:
{
  "description": "Detailed description of what's shown in the image",
  "category": "exterior|interior|kitchen|bathroom|bedroom|livingroom|dining|living|other",
  "features": ["list", "of", "notable", "features"],
  "storyText": "Compelling narrative description for marketing",
  "roomType": "kitchen|bathroom|bedroom|livingroom|dining|office|exterior|room",
  "confidence": number_from_1_to_10
}

Focus on architectural details, lighting, finishes, and selling points. Make the storyText engaging and highlight unique features.`;

      const result = await model.generateContent([prompt, imagePart]);
      const response = await result.response;
      const text = response.text();

      try {
        const analysis = JSON.parse(text);
        results.push({
          description: analysis.description || "Beautiful property feature",
          category: analysis.category || "other",
          features: analysis.features || [],
          storyText: analysis.storyText || analysis.description || "Stunning property detail",
          roomType: analysis.roomType || "room",
          confidence: analysis.confidence || 8
        });
      } catch (parseError) {
        console.warn('Failed to parse Gemini response for photo', i, parseError);
        results.push({
          description: "Beautiful property feature captured in this image",
          category: "other",
          features: [],
          storyText: "This image showcases an attractive aspect of the property",
          roomType: "room",
          confidence: 7
        });
      }
    } catch (error) {
      console.error('Error analyzing photo', i, error);
      results.push({
        description: "Property feature",
        category: "other",
        features: [],
        storyText: "Featured property detail",
        roomType: "room",
        confidence: 5
      });
    }
  }

  return results;
};

// Generate MLS description using Gemini Pro
export const generateMLSWithGemini = async (
  propertyInfo: string,
  propertyType?: PropertyType
): Promise<string> => {
  const gemini = await initializeGemini();
  const model = gemini!.getGenerativeModel({ model: "gemini-1.5-pro" });

  const typeContext = propertyType ? `Property Type: ${propertyType}\n` : '';
  
  const prompt = `Create a compelling MLS property description based on the following information:

${typeContext}Property Information:
${propertyInfo}

Requirements:
- Write in a professional, engaging tone
- Highlight unique selling points
- Include relevant keywords for searchability
- Keep under 500 words
- Focus on benefits and lifestyle
- Use active voice
- Avoid generic phrases

Generate only the MLS description text, no additional formatting or explanations.`;

  const result = await model.generateContent(prompt);
  const response = await result.response;
  return response.text().trim();
};

// Modify existing description
export const modifyDescription = async (
  modificationType: string,
  originalInput: string,
  currentDescription: string,
  customRequest?: string
): Promise<string> => {
  const gemini = await initializeGemini();
  const model = gemini!.getGenerativeModel({ model: "gemini-1.5-pro" });

  let modificationPrompt: string;

  if (modificationType === 'custom' && customRequest) {
    modificationPrompt = `Modify the following property description based on this specific request: "${customRequest}"`;
  } else {
    const modificationStyles = {
      luxury: "Make it more luxurious and high-end, emphasizing premium features and exclusivity",
      emotional: "Make it more emotional and lifestyle-focused, helping buyers envision living there",
      practical: "Make it more practical and factual, focusing on functional benefits and features",
      concise: "Make it more concise while keeping all key selling points",
      detailed: "Make it more detailed and comprehensive, expanding on features and benefits"
    };

    modificationPrompt = modificationStyles[modificationType as keyof typeof modificationStyles] || 
                        "Improve the description to be more engaging and compelling";
  }

  const prompt = `${modificationPrompt}

Original Property Information:
${originalInput}

Current Description:
${currentDescription}

Generate only the modified description text, no additional formatting or explanations.`;

  const result = await model.generateContent(prompt);
  const response = await result.response;
  return response.text().trim();
};
