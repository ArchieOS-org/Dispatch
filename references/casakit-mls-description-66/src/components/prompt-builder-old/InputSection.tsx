import { Button } from "@/components/ui/button";
import { Loader2 } from "lucide-react";
import { PROPERTY_TYPES } from "./constants";
import type { PropertyType, PhotoInfo, MediaInfo } from "./types";
import { GoogleImportButton } from "./GoogleImportButton";
import { FileUploadButton } from "../listing-generator/FileUploadButton";
import { PhotoUploadSection } from "../listing-generator/PhotoUploadSection";

interface InputSectionProps {
  userInput: string;
  setUserInput: (input: string) => void;
  propertyType?: PropertyType;
  setPropertyType: (type: PropertyType | undefined) => void;
  photos: PhotoInfo[];
  media: MediaInfo[];
  setMedia: (media: MediaInfo[]) => void;
  isLoading: boolean;
  handleGoogleFormsImport: (data: any) => void;
  handleGenerate: () => Promise<void>;
}

export const InputSection = ({
  userInput,
  setUserInput,
  propertyType,
  setPropertyType,
  photos,
  media,
  setMedia,
  isLoading,
  handleGoogleFormsImport,
  handleGenerate,
}: InputSectionProps) => {
  const canGenerate = userInput.trim() && !isLoading;

  return (
    <div className="h-full flex flex-col space-y-8">
      {/* UI: Hero Section */}
      <div className="text-center py-12">
        <h1 className="text-4xl font-light tracking-tight text-foreground mb-4">
          Create Your Perfect Property Listing
        </h1>
        <p className="text-lg text-muted-foreground max-w-2xl mx-auto leading-relaxed font-light">
          Just tell us about your property. We'll make it irresistible.
        </p>
      </div>

      {/* UI: Property Type Selection */}
      <div className="space-y-4 animate-fade-in">
        <label className="text-lg font-medium text-foreground">Property Type (Optional)</label>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          {PROPERTY_TYPES.map(type => (
            <Button 
              key={type.type} 
              variant={propertyType === type.type ? "default" : "outline"} 
              onClick={() => setPropertyType(propertyType === type.type ? undefined : type.type)} 
              className="h-16 flex-col gap-1 p-4 text-left hover:shadow-sm transition-all"
            >
              <span className="font-semibold text-sm">{type.label}</span>
            </Button>
          ))}
        </div>
      </div>

      {/* UI: Property Information Section */}
      <div className="space-y-4 animate-fade-in">
        <label className="text-lg font-medium text-foreground">Property Information</label>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <GoogleImportButton onPropertyDataImport={handleGoogleFormsImport} />
          <FileUploadButton media={media} onMediaChange={setMedia} maxFiles={50} />
          <PhotoUploadSection media={media} onMediaChange={setMedia} maxFiles={50} />
        </div>
      </div>

      {/* UI: Text Input Section */}
      <div className="space-y-4 animate-fade-in">
        <label className="text-lg font-medium text-foreground">Additional Details</label>
        <textarea 
          placeholder="Tell us everything else about your property - square footage, unique features, neighborhood details, recent renovations..."
          value={userInput} 
          onChange={e => setUserInput(e.target.value)} 
          className="w-full min-h-[120px] p-4 border rounded-lg resize-none bg-background"
          disabled={isLoading} 
        />
        <Button 
          onClick={handleGenerate} 
          disabled={!canGenerate} 
          className="w-full h-12 text-lg font-medium" 
          size="lg"
        >
          {isLoading ? (
            <>
              <Loader2 className="h-5 w-5 mr-2 animate-spin" />
              Generating Listing...
            </>
          ) : (
            "Generate Property Listing"
          )}
        </Button>
      </div>
    </div>
  );
};
