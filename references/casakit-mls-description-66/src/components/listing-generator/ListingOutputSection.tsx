import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Progress } from "@/components/ui/progress";
import { Copy, Check, Loader2 } from "lucide-react";
import { EnhancedMLSFields } from "./EnhancedMLSFields";
import { MinimalPhotoSorting } from "./MinimalPhotoSorting";
import type { EnhancedMLSFields as EnhancedMLSFieldsType, PropertyStoryWithEnhancedMLS } from "./enhanced-mls-types";
import type { MediaInfo } from "./types";

interface ListingOutputSectionProps {
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
  copyToClipboard: () => Promise<void>;
  resetBuilder: () => void;
  handleCustomModification: (request: string) => Promise<void>;
}

export const ListingOutputSection = ({
  media,
  setMedia,
  isLoading,
  analysisProgress,
  propertyStory,
  generatedResponse,
  remarksForClients,
  setRemarksForClients,
  copyToClipboard,
  resetBuilder,
  handleCustomModification,
}: ListingOutputSectionProps) => {
  const [mlsCopied, setMLSCopied] = useState(false);
  const [prompt, setPrompt] = useState("");
  const hasResult = Boolean(generatedResponse || propertyStory);
  const isAnalyzing = isLoading && analysisProgress.total > 0;

  // UI: Copy MLS description to clipboard
  const handleMLSCopy = async () => {
    const mlsText = remarksForClients || propertyStory?.mlsDescription || generatedResponse;
    if (mlsText) {
      await navigator.clipboard.writeText(mlsText);
      setMLSCopied(true);
      setTimeout(() => setMLSCopied(false), 2000);
    }
  };

  // Modification handled via top Remarks block


  return (
    <div className="space-y-6">
      {/* UI: Analysis Progress */}
      {isAnalyzing && (
        <div className="p-6 bg-background border rounded-lg animate-fade-in">
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
        </div>
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
          {/* Remarks for Clients (output) */}
          <div className="p-6 bg-background border rounded-lg space-y-3">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-medium text-foreground">Remarks for Clients</h3>
              <Button onClick={handleMLSCopy} variant="outline" className="gap-2">
                {mlsCopied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                {mlsCopied ? "Copied!" : "Copy"}
              </Button>
            </div>
            <div className="prose prose-sm max-w-none">
              <div className="whitespace-pre-wrap text-foreground leading-relaxed">
                {remarksForClients || propertyStory?.mlsFields?.comments?.remarksForClients || generatedResponse}
              </div>
            </div>
          </div>

          {/* Prompt input + regenerate */}
          <div className="p-6 bg-background border rounded-lg space-y-3">
            <h4 className="text-sm font-medium text-foreground">Refine with a prompt</h4>
            <Textarea
              value={prompt}
              onChange={e => setPrompt(e.target.value)}
              className="min-h-[120px] resize-y"
              placeholder="Describe how you'd like to regenerate the remarks..."
              disabled={isLoading}
            />
            <div className="flex gap-2">
              <Button onClick={async () => { if (prompt.trim()) { await handleCustomModification(prompt); } }} disabled={!prompt.trim() || isLoading}>
                {isLoading ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Regenerating...
                  </>
                ) : (
                  "Regenerate"
                )}
              </Button>
              <Button variant="outline" onClick={() => setPrompt("")}>Clear</Button>
            </div>
          </div>

        </div>
      )}


      {/* UI: Photo Output Section */}
      <div className="space-y-4">
        <h4 className="text-lg font-medium text-foreground">
          {media.filter(m => m.type === 'photo').length > 0 ? 'Photo Order' : 'Photo Placeholders'}
        </h4>
        <p className="text-sm text-muted-foreground">
          {media.filter(m => m.type === 'photo').length > 0 
            ? 'Arrange your photos in the order you want them to appear in the listing'
            : 'Upload photos to see them arranged here - shows the expected photo layout'
          }
        </p>
        <div className="p-6 bg-background border rounded-lg">
          <MinimalPhotoSorting 
            photos={media.filter(m => m.type === 'photo').map(m => ({
              id: m.id,
              file: m.file,
              url: m.url,
              category: m.category,
              analysis: m.analysis,
              roomType: m.roomType,
              confidence: m.confidence,
              sortOrder: m.sortOrder
            }))}
            onReorder={(reorderedPhotos) => {
              const otherMedia = media.filter(m => m.type !== 'photo');
              const updatedPhotos = reorderedPhotos.map(photo => ({
                ...photo,
                type: 'photo' as const
              }));
              setMedia([...otherMedia, ...updatedPhotos]);
            }}
            showPlaceholders={media.filter(m => m.type === 'photo').length === 0}
          />
        </div>
      </div>

      {/* UI: MLS Data Fields */}
      <div className="space-y-4">
        <h4 className="text-lg font-medium text-foreground">
          {propertyStory?.mlsFields ? 'MLS Data Fields' : 'MLS Data Template'}
        </h4>
        <p className="text-sm text-muted-foreground">
          {propertyStory?.mlsFields 
            ? 'Structured property data extracted from your description and photos'
            : 'Template showing all available MLS fields - will be populated when you generate a listing'
          }
        </p>
        <div className="p-6 bg-background border rounded-lg">
          <EnhancedMLSFields 
            mlsFields={(propertyStory?.mlsFields as EnhancedMLSFieldsType) || {}} 
            readOnly={true} 
          />
        </div>
      </div>
    </div>
  );
};