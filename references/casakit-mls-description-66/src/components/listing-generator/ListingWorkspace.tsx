// MAIN: Primary application screen component for React Native migration
import { useToast } from "@/hooks/use-toast";
import type { PropertyType, PhotoInfo, MediaInfo } from "./types";
import type { PropertyStoryWithEnhancedMLS } from "./enhanced-mls-types";
import { PropertyInputSection } from "./PropertyInputSection";
import { ListingOutputSection } from "./ListingOutputSection";

// UI: Interface for main screen properties
interface ListingWorkspaceProps {
  userInput: string;
  setUserInput: (input: string) => void;
  propertyType?: PropertyType;
  setPropertyType: (type: PropertyType | undefined) => void;
  photos: PhotoInfo[];
  setPhotos: (photos: PhotoInfo[]) => void;
  media: MediaInfo[];
  setMedia: (media: MediaInfo[]) => void;
  isLoading: boolean;
  analysisProgress: {
    current: number;
    total: number;
    stage: string;
  };
  propertyStory: PropertyStoryWithEnhancedMLS | null;
  generatedResponse: string;
  remarksForClients: string;
  setRemarksForClients: (text: string) => void;

  // CORE: Handler functions
  copyToClipboard: () => Promise<void>;
  resetBuilder: () => void;
  handlePhotoAnalysisComplete: () => Promise<void>;
  handleGenerateDescription: () => Promise<void>;
  handleCustomModification: (request: string) => Promise<void>;
  showOutputScreen?: boolean;
  onStartOutputScreen?: () => void;
}

export const ListingWorkspace = ({
  userInput,
  setUserInput,
  propertyType,
  setPropertyType,
  photos,
  setPhotos,
  media,
  setMedia,
  isLoading,
  analysisProgress,
  propertyStory,
  generatedResponse,
  setGeneratedResponse,
  remarksForClients,
  setRemarksForClients,
  copyToClipboard,
  resetBuilder,
  handlePhotoAnalysisComplete,
  handleGenerateDescription,
  handleCustomModification,
  showOutputScreen,
  onStartOutputScreen,
}: ListingWorkspaceProps) => {
  const { toast } = useToast();

  // API: Handle Google Forms data import
  const handleGoogleFormsImport = (data: any) => {
    if (data.propertyInfo) {
      setUserInput(data.propertyInfo);
    }
    if (data.propertyType) {
      setPropertyType(data.propertyType);
    }
    toast({
      title: "Data Imported",
      description: "Property information imported from Google Forms"
    });
  };

  // CORE: Main generation handler - simplified for mobile
  const handleGenerate = async () => {
    if (photos.length > 0) {
      await handlePhotoAnalysisComplete();
    } else {
      await handleGenerateDescription();
    }
    onStartOutputScreen?.();
  };

  const hasStartedOutput = isLoading || Boolean(generatedResponse || propertyStory);

  return (
    <div className="h-screen bg-background flex flex-col">
      <div className="flex-1 max-w-7xl mx-auto w-full min-h-0">
        {/* MAIN: Single Scrollable Container */}
        <div className="h-full overflow-y-auto">
          <div className="p-6 space-y-6">
            {showOutputScreen ? (
              <ListingOutputSection
                media={media}
                setMedia={setMedia}
                isLoading={isLoading}
                analysisProgress={analysisProgress}
                propertyStory={propertyStory}
                generatedResponse={generatedResponse}
                remarksForClients={remarksForClients}
                setRemarksForClients={setRemarksForClients}
                copyToClipboard={copyToClipboard}
                resetBuilder={resetBuilder}
                handleCustomModification={handleCustomModification}
              />
            ) : (
              <PropertyInputSection
                userInput={userInput}
                setUserInput={setUserInput}
                propertyType={propertyType}
                setPropertyType={setPropertyType}
                photos={photos}
                media={media}
                setMedia={setMedia}
                isLoading={isLoading}
                handleGoogleFormsImport={handleGoogleFormsImport}
                handleGenerate={handleGenerate}
              />
            )}
          </div>
          
          {/* Bottom padding for better scroll experience */}
          <div className="h-6"></div>
        </div>
      </div>
    </div>
  );
};