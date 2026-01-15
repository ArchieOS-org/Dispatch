
import OpenAI from 'openai';
import { supabase } from '@/integrations/supabase/client';
import type { ModificationType, PropertyType } from './types';

const getOpenAIClient = async () => {
  const { data, error } = await supabase.functions.invoke('get-secret', {
    body: { name: 'OPENAI_API_KEY' }
  });

  if (error || !data?.value) {
    throw new Error('OpenAI API key not configured. Please set it up in the settings.');
  }

  return new OpenAI({
    apiKey: data.value,
    dangerouslyAllowBrowser: true
  });
};

export const generateMLSWithOpenAI = async (input: string, propertyType?: PropertyType) => {
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

  const prompt = `You are an expert Toronto/GTA real-estate copywriter. Write a compelling, character-efficient MLS description that meets TREB rules.

TASK INSTRUCTIONS:
1. Open with a punchy hook (pick or adapt ONE):
   • "A Homeowner's Dream!"
   • "Impeccably Maintained!"
   • "Opportunity Knocks To Own This Immaculate/Magnificent…"
   • "Calling All Builders & Investors!"
   • "Location, Location, Location!"
   • "Your Search Stops Here!"
   • "Spectacular Luxury Living In…"
   • "Masterful Contemporary Design Home In Sought-After…"
   • "Perfect Pied-à-Terre In The Heart Of Mississauga…"

2. Walk the reader through the home in this order:
   a. Square footage / total living space
   b. Kitchen highlights (appliances, finishes, layout)
   c. Main living/dining areas
   d. Upper-level bedrooms & baths
   e. Basement features
   f. Backyard & exterior perks

3. Use vivid, concise language; minimum 1500 characters, maximum 2000 characters total.

4. Output ONLY the property description as plain text with no formatting, bullets, or special characters.

5. Do NOT include brokerage remarks, inclusions, exclusions, or any legal text.${getPropertyTypeGuidance(propertyType)}

Here is the property information to work with:
${input}

Write only the description text, nothing else:`;

  try {
    const openai = await getOpenAIClient();
    
    const response = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [{ role: "user", content: prompt }],
      max_tokens: 1000,
      temperature: 0.7,
    });

    return response.choices[0]?.message?.content || "";
  } catch (error) {
    console.error("Error calling OpenAI API:", error);
    throw new Error("Failed to generate MLS description. Please check your API key and try again.");
  }
};

export const modifyDescription = async (
  modificationType: ModificationType,
  originalInput: string,
  currentDescription: string,
  customRequest?: string
) => {
  let modificationPrompt = "";
  
  if (modificationType === "custom" && customRequest) {
    modificationPrompt = `Rewrite this MLS description based on this specific request: "${customRequest}". Make the changes while maintaining professionalism and accuracy.`;
  } else {
    switch(modificationType) {
      case "luxury":
        modificationPrompt = "Rewrite this MLS description to emphasize luxury, premium finishes, and high-end features. Use more sophisticated language and highlight exclusive elements.";
        break;
      case "emotional":
        modificationPrompt = "Rewrite this MLS description with more emotional appeal. Use words that help buyers envision their dream lifestyle in this home.";
        break;
      case "practical":
        modificationPrompt = "Rewrite this MLS description to be more practical and factual. Focus on functional benefits and measurable features.";
        break;
      case "concise":
        modificationPrompt = "Rewrite this MLS description to be more concise while keeping all key selling points and staying within character limits.";
        break;
      case "detailed":
        modificationPrompt = "Rewrite this MLS description to be more detailed and comprehensive, expanding on features and benefits while staying within character limits.";
        break;
    }
  }

  const prompt = `${modificationPrompt}

Original property information:
${originalInput}

Current description:
${currentDescription}

Requirements:
- Keep it between 1500-2000 characters
- Plain text only, no formatting
- Focus on the modification requested while maintaining accuracy
- Do not include brokerage remarks, inclusions, or exclusions

Write only the modified description:`;

  try {
    const openai = await getOpenAIClient();
    
    const response = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [{ role: "user", content: prompt }],
      max_tokens: 1000,
      temperature: 0.7,
    });

    return response.choices[0]?.message?.content || "";
  } catch (error) {
    console.error("Error calling OpenAI API:", error);
    throw new Error("Failed to modify description. Please try again.");
  }
};
