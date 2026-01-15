import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import { Progress } from "@/components/ui/progress";
import { Copy, Check, Loader2 } from "lucide-react";
import { MinimalPhotoSorting } from "../listing-generator/MinimalPhotoSorting";
import { MinimalMLSFields } from "../listing-generator/MinimalMLSFields";
import type { PhotoInfo, MediaInfo } from "./types";
import type { PropertyStoryWithMLS } from "./mls-types";

interface OutputSectionProps {
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
  copyToClipboard: () => Promise<void>;
  resetBuilder: () => void;
  handleCustomModification: (request: string) => Promise<void>;
}

export const OutputSection = ({
  media,
  setMedia,
  isLoading,
  analysisProgress,
  propertyStory,
  generatedResponse,
  copyToClipboard,
  resetBuilder,
  handleCustomModification,
}: OutputSectionProps) => {
  const [modificationRequest, setModificationRequest] = useState("");
  const [copied, setCopied] = useState(false);

  const hasResult = generatedResponse || propertyStory;
  const isAnalyzing = isLoading && analysisProgress.total > 0;

  // UTILS: Convert media photos to PhotoInfo format for sorting
  const convertMediaToPhotos = (media: MediaInfo[]): PhotoInfo[] => {
    return media.filter(m => m.type === 'photo').map((m, index) => ({
      id: m.id,
      file: m.file,
      url: m.url,
      category: m.category || 'other',
      analysis: m.analysis,
      roomType: m.roomType,
      confidence: m.confidence,
      sortOrder: m.sortOrder || index
    }));
  };

  const sortablePhotos = convertMediaToPhotos(media);

  // UI: Handle photo reordering for mobile-friendly interface
  const handlePhotoReorder = (reorderedPhotos: PhotoInfo[]) => {
    const updatedMedia = [...media];
    const mediaPhotoMap = new Map(media.filter(m => m.type === 'photo').map(m => [m.id, m]));
    
    reorderedPhotos.forEach((photo, index) => {
      const mediaItem = mediaPhotoMap.get(photo.id);
      if (mediaItem) {
        mediaItem.sortOrder = index;
      }
    });

    updatedMedia.sort((a, b) => {
      if (a.type === 'photo' && b.type === 'photo') {
        return (a.sortOrder || 0) - (b.sortOrder || 0);
      }
      return 0;
    });
    setMedia(updatedMedia);
  };

  // UI: Copy to clipboard functionality
  const handleCopy = async () => {
    await copyToClipboard();
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // CORE: Handle custom modifications to generated description
  const handleModify = async () => {
    if (modificationRequest.trim()) {
      await handleCustomModification(modificationRequest);
      setModificationRequest("");
    }
  };

  return (
    <div className="space-y-6">
      {/* UI: Analysis Progress */}
      {isAnalyzing && (
        <Card className="p-6 bg-gradient-to-br from-primary/5 to-primary/10 border-primary/20 animate-fade-in">
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="space-y-1">
                <p className="text-sm font-medium text-foreground">
                  {analysisProgress.stage}
                </p>
                <p className="text-xs text-muted-foreground">
                  Processing {analysisProgress.current} of {analysisProgress.total} items
                </p>
              </div>
              <div className="text-sm font-medium text-primary">
                {Math.round(analysisProgress.current / analysisProgress.total * 100)}%
              </div>
            </div>
            <Progress value={analysisProgress.current / analysisProgress.total * 100} className="h-2" />
          </div>
        </Card>
      )}

      {/* UI: Loading State */}
      {isLoading && !isAnalyzing && (
        <div className="flex items-center justify-center py-8 animate-fade-in">
          <div className="flex items-center gap-3">
            <Loader2 className="h-6 w-6 animate-spin text-primary" />
            <span className="text-lg font-light text-muted-foreground">
              Crafting your complete listing...
            </span>
          </div>
        </div>
      )}

      {/* UI: Results Section */}
      {hasResult && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex items-center justify-between">
            <h3 className="text-xl font-medium text-foreground">Generated MLS Description</h3>
            <div className="flex gap-2">
              <Button onClick={handleCopy} variant="outline" className="gap-2">
                {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                {copied ? "Copied!" : "Copy"}
              </Button>
              <Button onClick={resetBuilder} variant="outline">
                Start Over
              </Button>
            </div>
          </div>

          <Card className="bg-gradient-to-br from-primary/5 to-primary/10 border-primary/20">
            <CardContent className="p-6">
              <div className="prose prose-sm max-w-none">
                <div className="whitespace-pre-wrap text-foreground leading-relaxed">
                  {generatedResponse || propertyStory?.mlsDescription}
                </div>
              </div>
            </CardContent>
          </Card>

          {/* UI: Modification Section */}
          <Card className="border-dashed">
            <CardHeader>
              <CardTitle className="text-lg">Want to modify the description?</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <Textarea 
                placeholder="Describe how you'd like to modify the description (e.g., 'Make it more luxury focused' or 'Add emphasis on the location')" 
                value={modificationRequest} 
                onChange={e => setModificationRequest(e.target.value)} 
                className="min-h-[80px] resize-none" 
              />
              <Button onClick={handleModify} disabled={!modificationRequest.trim() || isLoading} className="w-full">
                {isLoading ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Modifying...
                  </>
                ) : (
                  "Modify Description"
                )}
              </Button>
            </CardContent>
          </Card>

          {/* UI: Photo Sorting */}
          {sortablePhotos.length > 0 && (
            <Card className="overflow-hidden">
              <CardContent className="p-6">
                <MinimalPhotoSorting photos={sortablePhotos} onReorder={handlePhotoReorder} />
              </CardContent>
            </Card>
          )}

          {/* UI: MLS Data Fields */}
          {propertyStory?.mlsFields && (
            <Card className="overflow-hidden">
              <CardHeader>
                <CardTitle className="text-lg font-medium text-foreground">
                  MLS Data Fields
                </CardTitle>
                <CardDescription className="text-sm text-muted-foreground">
                  Structured property data extracted from your description and photos
                </CardDescription>
              </CardHeader>
              <CardContent className="p-6 pt-0">
                <MinimalMLSFields mlsFields={propertyStory.mlsFields} readOnly={true} />
              </CardContent>
            </Card>
          )}
        </div>
      )}
    </div>
  );
};
