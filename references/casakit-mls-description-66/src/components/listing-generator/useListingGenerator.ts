// CORE: Main business logic hook for React Native migration
import { useState, useEffect } from "react";
import { useToast } from "@/hooks/use-toast";
import type { ModificationType, PropertyType, PhotoInfo, MediaInfo } from "./types";
import type { PropertyStoryWithEnhancedMLS, EnhancedMLSFields } from "./enhanced-mls-types";
import type { useSessionManager } from "./useSessionManager";

export const useListingGenerator = (sessionManager?: ReturnType<typeof useSessionManager>) => {
  const [userInput, setUserInput] = useState("");
  const [originalInput, setOriginalInput] = useState("");
  const [generatedResponse, setGeneratedResponse] = useState("");
  const [remarksForClients, setRemarksForClients] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [propertyType, setPropertyType] = useState<PropertyType | undefined>();
  const [photos, setPhotos] = useState<PhotoInfo[]>([]);
  const [media, setMedia] = useState<MediaInfo[]>([]);
  const [analysisProgress, setAnalysisProgress] = useState({ current: 0, total: 0, stage: '' });
  const [propertyStory, setPropertyStory] = useState<PropertyStoryWithEnhancedMLS | null>(null);
  // REMOVED: Chat functionality for mobile migration
  const [photoAnalyses, setPhotoAnalyses] = useState<any[]>([]);
  const { toast } = useToast();

  // Auto-save to session when state changes
  useEffect(() => {
    if (sessionManager?.currentSessionId) {
      sessionManager.updateSessionData({
        userInput,
        propertyType: propertyType || '',
        photos: photos.map(p => p.file),
        media: media.map(m => m.file),
        generatedDescription: generatedResponse,
        photoAnalyses,
        propertyStory: propertyStory?.mlsDescription || '',
      });
    }
  }, [userInput, propertyType, photos, media, generatedResponse, photoAnalyses, propertyStory, sessionManager]);

  const copyToClipboard = async () => {
    try {
      const textToCopy = remarksForClients || propertyStory?.mlsDescription || generatedResponse;
      await navigator.clipboard.writeText(textToCopy);
      toast({
        title: "Copied to clipboard!",
        description: "The MLS description has been copied.",
      });
    } catch (err) {
      toast({
        title: "Copy failed",
        description: "Please select and copy the text manually.",
        variant: "destructive",
      });
    }
  };

  const resetBuilder = async () => {
    setUserInput("");
    setOriginalInput("");
    setGeneratedResponse("");
    setPropertyType(undefined);
    setPropertyStory(null);
    setPhotos([]);
    setMedia([]);
    setPhotoAnalyses([]);
    
    // Create a new session when resetting
    if (sessionManager) {
      await sessionManager.createSession();
    }
  };

  const createEmptyPropertyStory = (): PropertyStoryWithEnhancedMLS => {
    const mockMLSFields: EnhancedMLSFields = {
      location: {},
      amounts: {},
      exterior: {},
      waterfront: {},
      interior: {},
      comments: {
        remarksForClients: "This is a sample MLS description that would be generated based on your property information. The description would highlight key features, location benefits, and selling points to attract potential buyers."
      },
      other: {}
    };

    return {
      mlsDescription: "This is a sample MLS description that would be generated based on your property information. The description would highlight key features, location benefits, and selling points to attract potential buyers.",
      storyText: "This is where the property walkthrough narrative would appear, taking potential buyers on a virtual tour through the home from entrance to exit.",
      mlsFields: mockMLSFields,
      propertyHighlights: [
        "Sample highlight 1",
        "Sample highlight 2", 
        "Sample highlight 3"
      ],
      marketingTags: [
        "Move-in Ready",
        "Great Location",
        "Must See"
      ]
    };
  };

  const handlePhotoAnalysisComplete = async () => {
    if (!userInput.trim()) return;
    
    setOriginalInput(userInput);
    setIsLoading(true);
    
    try {
      // Simulate analysis progress for photos
      if (photos.length > 0) {
        for (let i = 0; i <= photos.length; i++) {
          setAnalysisProgress({ 
            current: i, 
            total: photos.length, 
            stage: i === photos.length ? 'Generating description...' : `Analyzing photo ${i + 1}...` 
          });
          await new Promise(resolve => setTimeout(resolve, 500));
        }
        
        // Update photos with mock analysis data
        const updatedPhotos = photos.map((photo, index) => ({
          ...photo,
          analysis: `This is a sample analysis for photo ${index + 1}`,
          category: 'other' as const,
          roomType: 'room' as const,
          confidence: 8
        }));
        
        setPhotos(updatedPhotos);
      }
      
      // Create empty property story
      const story = createEmptyPropertyStory();
      setPropertyStory(story);
      setGeneratedResponse(story.mlsDescription);
      setRemarksForClients(
        story.mlsFields?.comments?.remarksForClients || story.mlsDescription
      );
      
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to generate description",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
      setAnalysisProgress({ current: 0, total: 0, stage: '' });
    }
  };

  const handleGenerateDescription = async () => {
    setOriginalInput(userInput);
    setIsLoading(true);
    
    try {
      // Brief loading simulation
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Create empty property story
      const story = createEmptyPropertyStory();
      setPropertyStory(story);
      setGeneratedResponse(story.mlsDescription);
      setRemarksForClients(
        story.mlsFields?.comments?.remarksForClients || story.mlsDescription
      );
      
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to generate description",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleInsufficientInfoContinue = async (additionalInfo: Record<string, string>) => {
    setIsLoading(true);
    try {
      // Brief loading simulation
      await new Promise(resolve => setTimeout(resolve, 800));
      
      // Create empty property story with updated description
      const story = createEmptyPropertyStory();
      story.mlsDescription = "Updated MLS description based on additional information provided. This would incorporate the new details to create a more comprehensive property description.";
      // Keep remarks in sync with MLS description for now
      if (!story.mlsFields) (story as any).mlsFields = { comments: {} } as any;
      (story.mlsFields as any).comments = (story.mlsFields as any).comments || {};
      (story.mlsFields as any).comments.remarksForClients = story.mlsDescription;

      setGeneratedResponse(story.mlsDescription);
      setPropertyStory(story);
      setRemarksForClients(story.mlsDescription);
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to generate description",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleModification = async (modificationType: ModificationType) => {
    setIsLoading(true);
    try {
      // Brief loading simulation
      await new Promise(resolve => setTimeout(resolve, 600));
      
      const modificationTexts = {
        luxury: "This would be the luxury-focused version of your MLS description, emphasizing high-end features and premium amenities.",
        emotional: "This would be the emotionally-engaging version of your MLS description, focusing on lifestyle and feelings.",
        concise: "This would be the concise version of your MLS description, highlighting only the most important features.",
        technical: "This would be the technical version of your MLS description, focusing on specifications and measurements."
      };
      
      const response = modificationTexts[modificationType] || "Modified description based on your request.";
      setGeneratedResponse(response);
      setRemarksForClients(response);
      // Keep MLS fields/story in sync if present
      setPropertyStory(prev => {
        if (!prev) return prev;
        const updated = { ...prev };
        updated.mlsDescription = response;
        if (!updated.mlsFields) (updated as any).mlsFields = { comments: {} } as any;
        (updated.mlsFields as any).comments = (updated.mlsFields as any).comments || {};
        (updated.mlsFields as any).comments.remarksForClients = response;
        return updated;
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to modify description",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleCustomModification = async (request: string) => {
    if (!request.trim()) return;
    
    setIsLoading(true);
    try {
      // Brief loading simulation
      await new Promise(resolve => setTimeout(resolve, 600));
      
      const response = `Modified description based on your request: "${request}". This would be the updated version incorporating your specific changes.`;
      setGeneratedResponse(response);
      setRemarksForClients(response);
      // Keep MLS fields/story in sync if present
      setPropertyStory(prev => {
        if (!prev) return prev;
        const updated = { ...prev };
        updated.mlsDescription = response;
        if (!updated.mlsFields) (updated as any).mlsFields = { comments: {} } as any;
        (updated.mlsFields as any).comments = (updated.mlsFields as any).comments || {};
        (updated.mlsFields as any).comments.remarksForClients = response;
        return updated;
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to modify description",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return {
    // State
    userInput,
    setUserInput,
    originalInput,
    generatedResponse,
    setGeneratedResponse,
    remarksForClients,
    setRemarksForClients,
    isLoading,
    propertyType,
    setPropertyType,
    photos,
    setPhotos,
    media,
    setMedia,
    analysisProgress,
    propertyStory,
    setPropertyStory,
    photoAnalyses,
    setPhotoAnalyses,
    
    // Handlers
    copyToClipboard,
    resetBuilder,
    handlePhotoAnalysisComplete,
    handleGenerateDescription,
    handleInsufficientInfoContinue,
    handleModification,
    handleCustomModification,
  };
};