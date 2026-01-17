// MAIN: Primary application screen component for React Native migration
import { useToast } from "@/hooks/use-toast";
import type { PropertyType, PhotoInfo, MediaInfo } from "./types";
import type { PropertyStoryWithMLS } from "./mls-types";
import { InputSection } from "./InputSection";
import { OutputSection } from "./OutputSection";

// UI: Interface for main screen properties
interface HomeScreenProps {
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
  propertyStory: PropertyStoryWithMLS | null;
  generatedResponse: string;

  // CORE: Handler functions
  copyToClipboard: () => Promise<void>;
  resetBuilder: () => void;
  handlePhotoAnalysisComplete: () => Promise<void>;
  handleGenerateDescription: () => Promise<void>;
  handleCustomModification: (request: string) => Promise<void>;
}

export const HomeScreen = ({
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
  copyToClipboard,
  resetBuilder,
  handlePhotoAnalysisComplete,
  handleGenerateDescription,
  handleCustomModification,
}: HomeScreenProps) => {
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
  };

  return (
    <div className="h-full bg-background flex flex-col">
      <div className="flex-1 max-w-7xl mx-auto w-full flex flex-col min-h-0">
        {/* MAIN: Content Area - Full width responsive */}
        <div className="flex-1 w-full overflow-y-auto">
          <div className="p-6 h-full flex flex-col">
            {/* Input Section - Dynamic height */}
            <div className="flex-1 min-h-0">
              <InputSection
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
            </div>

            {/* Output Section */}
            <OutputSection
              media={media}
              setMedia={setMedia}
              isLoading={isLoading}
              analysisProgress={analysisProgress}
              propertyStory={propertyStory}
              generatedResponse={generatedResponse}
              copyToClipboard={copyToClipboard}
              resetBuilder={resetBuilder}
              handleCustomModification={handleCustomModification}
            />
          </div>
        </div>
      </div>
    </div>
  );
};