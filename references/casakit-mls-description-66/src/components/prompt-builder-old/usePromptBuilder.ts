// CORE: Main business logic hook for React Native migration
import { useState, useEffect } from "react";
import { useToast } from "@/hooks/use-toast";
import { generateMLSWithGemini, modifyDescription, analyzePhotos } from "./gemini-service";
import { generatePropertyStory } from "./generatePropertyStory";
import type { ModificationType, PropertyType, PhotoInfo, MediaInfo } from "./types";
import type { PropertyStory } from "./gemini-service";
import type { PropertyStoryWithMLS } from "./mls-types";
import type { useSessionManager } from "./useSessionManager";

export const usePromptBuilder = (sessionManager?: ReturnType<typeof useSessionManager>) => {
  const [userInput, setUserInput] = useState("");
  const [originalInput, setOriginalInput] = useState("");
  const [generatedResponse, setGeneratedResponse] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [propertyType, setPropertyType] = useState<PropertyType | undefined>();
  const [photos, setPhotos] = useState<PhotoInfo[]>([]);
  const [media, setMedia] = useState<MediaInfo[]>([]);
  const [analysisProgress, setAnalysisProgress] = useState({ current: 0, total: 0, stage: '' });
  const [propertyStory, setPropertyStory] = useState<PropertyStoryWithMLS | null>(null);
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
      const textToCopy = propertyStory?.mlsDescription || generatedResponse;
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

  const handlePhotoAnalysisComplete = async () => {
    if (!userInput.trim()) return;
    
    setOriginalInput(userInput);
    setIsLoading(true);
    try {
      let photoAnalyses;
      
      // Analyze photos if any are uploaded
      if (photos.length > 0) {
        const photoFiles = photos.map(p => p.file);
        photoAnalyses = await analyzePhotos(photoFiles, (current, total, stage) => {
          setAnalysisProgress({ current, total, stage });
        });
        
        // Update photos with analysis data
        const updatedPhotos = photos.map((photo, index) => ({
          ...photo,
          analysis: photoAnalyses[index]?.description,
          category: photoAnalyses[index]?.category || 'other',
          roomType: photoAnalyses[index]?.roomType,
          confidence: photoAnalyses[index]?.confidence
        }));
        
        setPhotos(updatedPhotos);
        
        // Generate description after photo analysis
        const story = await generatePropertyStory(userInput, propertyType, photoAnalyses);
        setPropertyStory(story);
        setGeneratedResponse(story.mlsDescription);
      } else {
        // No photos, proceed directly to generation
        const response = await generateMLSWithGemini(userInput, propertyType);
        setGeneratedResponse(response);
      }
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to analyze photos",
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
      // Get photo analyses for generation
      const photoAnalyses = photos.map(photo => ({
        description: photo.analysis || "",
        category: photo.category || "other" as const,
        features: [], // Empty features array as photos already analyzed
        storyText: photo.analysis || "",
        roomType: photo.roomType || "room",
        confidence: photo.confidence || 8
      }));

      const story = await generatePropertyStory(userInput, propertyType, photoAnalyses);
      
      setPropertyStory(story);
      setGeneratedResponse(story.mlsDescription);
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to generate description",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleInsufficientInfoContinue = async (additionalInfo: Record<string, string>) => {
    setIsLoading(true);
    try {
      // Combine original input with additional info
      let enhancedInput = userInput;
      
      Object.entries(additionalInfo).forEach(([label, value]) => {
        enhancedInput += `\n${label}: ${value}`;
      });
      
      const response = await generateMLSWithGemini(enhancedInput, propertyType);
      setGeneratedResponse(response);
      setPropertyStory(null); // Clear story when regenerating
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to generate description",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleModification = async (modificationType: ModificationType) => {
    setIsLoading(true);
    try {
      const response = await modifyDescription(modificationType, originalInput, generatedResponse);
      setGeneratedResponse(response);
      setPropertyStory(null); // Clear story when modifying
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to modify description",
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
      const response = await modifyDescription("custom" as ModificationType, originalInput, generatedResponse, request);
      setGeneratedResponse(response);
      setPropertyStory(null); // Clear story when modifying
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to modify description",
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