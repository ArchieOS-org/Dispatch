
/**
 * PROPERTY STORY GENERATOR: AI-powered comprehensive property story creation
 * 
 * This module generates complete property stories including:
 * - MLS descriptions optimized for search and appeal
 * - Structured property data fields for MLS systems
 * - Marketing copy with emotional hooks
 * - Feature highlights and selling points
 * 
 * Integrates with Google Gemini for intelligent content generation
 * based on user input, photos, and property type preferences.
 */

import { GoogleGenerativeAI } from "@google/generative-ai";
import type { PropertyType } from "./types";
import type { PhotoAnalysis, PropertyStory } from "./gemini-service";
import type { PropertyStoryWithMLS } from "./mls-types";

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
): Promise<PropertyStoryWithMLS> => {
  const getPropertyTypeGuidance = (type?: PropertyType) => {
    if (!type) return "";
    
    const guidance = {
      luxury: "Focus on premium materials, high-end appliances, exclusive features, and sophisticated design elements.",
      family: "Emphasize spacious rooms, safety features, storage, proximity to schools, and family-friendly amenities.", 
      investment: "Highlight rental potential, location desirability, maintenance costs, and return on investment factors.",
      starter: "Emphasize affordability, move-in readiness, low maintenance, and starter home appeal.",
      vacation: "Focus on relaxation, recreational amenities, scenic views, and getaway appeal.",
      commercial: "Highlight business potential, location advantages, foot traffic, and commercial features.",
      land: "Emphasize development potential, location benefits, zoning, and investment opportunities."
    };
    
    return `\n\nProperty Type Focus: ${guidance[type]}`;
  };

  // Use photos in their current order
  const sortedPhotos = [...photoAnalyses];

  const prompt = `You are an expert real estate storyteller and MLS data analyst. Create a cohesive property walkthrough story, professional MLS description, and populate comprehensive MLS fields.

TASK: Generate walkthrough narrative, MLS description, AND extract/populate all relevant MLS fields from the provided information.

WALKTHROUGH STORY REQUIREMENTS:
- Create a flowing narrative that guides readers through the property
- Each photo should connect naturally to the next
- Use elegant, descriptive language that paints a vivid picture
- Start with arrival/exterior and flow logically through the home
- End with outdoor spaces or final selling points
- 800-1200 characters for the walkthrough story

MLS DESCRIPTION REQUIREMENTS:
- Professional TREB-compliant format
- 1500-2000 characters
- Include specific details only if provided
- Use punchy opening hook
- Focus on features confirmed in photos and property details
- Plain text, no formatting

MLS FIELDS REQUIREMENTS:
- Extract and populate ALL relevant fields from the provided information
- Use intelligent inference when possible (e.g., if pool visible in photos, set pool: true)
- Leave fields null if no information available
- Be precise with numbers and measurements
- Categorize features appropriately

PHOTO FLOW GUIDANCE:
${sortedPhotos.map((photo, index) => `
Photo ${index + 1}: ${photo.description}
Category: ${photo.category}
Story context: ${photo.storyText || 'Continue the narrative flow'}
Features: ${photo.features.join(', ')}
`).join('')}

PROPERTY INFORMATION:
${input}

${getPropertyTypeGuidance(propertyType)}

Respond with ONLY a JSON object following this exact structure:
{
  "walkthrough": "flowing narrative story connecting all photos",
  "mlsDescription": "professional MLS description text",
  "mlsFields": {
    "address": {
      "apartmentUnit": null,
      "streetDirection": null
    },
    "basic": {
      "brokerage": null,
      "member": null,
      "propertyClass": "Residential",
      "propertyType": "Detached",
      "searchBy": null,
      "searchByAddress": null,
      "transactionType": "Sale"
    },
    "exterior": {
      "parkingSpacesDrive": null,
      "parkingSpacesTotal": null,
      "approximateAge": null,
      "approximateSquareFootage": null,
      "belowGradeFinishedSQFT": null,
      "belowGradeFinishedSQFTSource": null,
      "cable": null,
      "driveParkingSpaces": null,
      "exterior": null,
      "foundationDetail": null,
      "garage": null,
      "garageParkingSpaces": null,
      "garageType": null,
      "gasNatural": null,
      "heatSource": null,
      "heatType": null,
      "hydro": null,
      "interiorFeatures": [],
      "otherSQFT": null,
      "otherStructures": [],
      "parcelOfTiedLand": null,
      "parkingDrive": null,
      "pool": null,
      "propertyFeatures": [],
      "roof": null,
      "securityFeatures": [],
      "sewer": null,
      "specialDesignation": null,
      "style": null,
      "surveyType": null,
      "surveyYear": null,
      "telephone": null,
      "topography": null,
      "totalUnfinishedSQFT": null,
      "water": null,
      "waterMeter": null,
      "waterSupplyType": null,
      "wellCapacity": null,
      "wellDepth": null,
      "yearBuilt": null,
      "yearBuiltSource": null
    },
    "interior": {
      "bedrooms": null,
      "bedroomsPlus": null,
      "kitchens": null,
      "rooms": null,
      "roomsPlus": null,
      "airConditioning": null,
      "basement": null,
      "familyRoomBonusRoom": null,
      "fireplaceStove": null,
      "heatSource": null,
      "heatType": null,
      "interiorFeatures": [],
      "laundryLevel": null,
      "numberOfFireplaces": null,
      "uffi": null,
      "underContract": null,
      "washroom1": null,
      "washroom2": null
    },
    "location": {
      "abbreviation": null,
      "area": null,
      "community": null,
      "directions": null,
      "frontingOn": null,
      "legalDescription": null,
      "lotDepth": null,
      "lotFront": null,
      "lotSizeCode": null,
      "mainCrossStreets": null,
      "municipality": null,
      "pin": null,
      "postalCode": null,
      "streetName": null,
      "streetNumber": null,
      "waterfront": null,
      "zoning": null
    },
    "amounts": {
      "assessmentYear": null,
      "contractCommencement": null,
      "expiryDate": null,
      "hstApplicable": null,
      "holdoverDays": null,
      "listPrice": null,
      "localImprovements": null,
      "possessionRemarks": null,
      "possessionType": null,
      "sellerName": null,
      "taxYear": null,
      "taxes": null
    },
    "rooms": {
      "mainLivingRoom": null,
      "mainKitchen": null,
      "mainPrimaryBedroom": null,
      "mainBedroom": null,
      "basementRecreation": null,
      "basementBedroom": null,
      "basementLaundry": null
    },
    "utilities": {
      "cable": null,
      "gasNatural": null,
      "hydro": null,
      "municipalWater": null,
      "telephone": null
    },
    "waterfront": null
  }
}

Populate fields intelligently based on the provided information and photo analysis. Be precise and only include values you can confidently determine.`;

  try {
    const apiKey = await getGeminiKey();
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-pro" });
    
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text().trim();
    
    try {
      const parsed = JSON.parse(text);
      
      // Add URLs and IDs to photos for the final output
      const photosWithUrls = sortedPhotos.map((photo, index) => ({
        id: `photo-${index}`,
        url: '', // Will be populated by the component
        description: photo.description,
        category: photo.category,
        features: photo.features,
        storyText: photo.storyText
      }));
      
      return {
        walkthrough: parsed.walkthrough,
        mlsDescription: parsed.mlsDescription,
        photos: photosWithUrls,
        mlsFields: parsed.mlsFields
      };
    } catch {
      // Fallback if JSON parsing fails
      return {
        walkthrough: "Welcome to this exceptional property where every detail has been thoughtfully designed to create the perfect living experience.",
        mlsDescription: text.includes("INSUFFICIENT_INFO:") ? text : "A beautifully appointed home offering modern comfort and timeless elegance.",
        photos: sortedPhotos.map((photo, index) => ({
          id: `photo-${index}`,
          url: '',
          description: photo.description,
          category: photo.category,
          features: photo.features,
          storyText: photo.storyText
        })),
        mlsFields: {
          address: {},
          basic: { propertyClass: "Residential", transactionType: "Sale" },
          exterior: { interiorFeatures: [], otherStructures: [], propertyFeatures: [], securityFeatures: [] },
          interior: { interiorFeatures: [] },
          location: {},
          amounts: {},
          rooms: {},
          utilities: {}
        }
      };
    }
  } catch (error) {
    console.error("Error generating property story:", error);
    throw new Error("Failed to generate property story. Please check your API key and try again.");
  }
};
