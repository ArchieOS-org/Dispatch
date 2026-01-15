import { useState } from "react";
import { useListingGenerator } from "./useListingGenerator";
import { useSessionManager } from "./useSessionManager";
import { ListingWorkspace } from "./ListingWorkspace";
import { AppSidebar } from "../layout/AppSidebar";
import { AppHeader } from "./AppHeader";
import { SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { Button } from "@/components/ui/button";
import { Plus } from "lucide-react";

const ListingGenerator = () => {
  const sessionManager = useSessionManager();
  const listingGeneratorState = useListingGenerator(sessionManager);
  const [showOutputScreen, setShowOutputScreen] = useState(false);

  // Handle new session creation
  const handleNewSession = async () => {
    // Check if there's already an empty temp session
    const existingTempSession = sessionManager.sessions.find(s => s.id === 'temp-new-session');
    if (existingTempSession) {
      // If we're not currently on it, navigate to it
      if (sessionManager.currentSessionId !== 'temp-new-session') {
        await handleSessionSelect('temp-new-session');
      }
      // If we're already on it, do nothing (stay there)
      return;
    }
    
    // Only create a new session if no empty temp session exists
    const sessionId = await sessionManager.createSession();
    if (sessionId) {
      await handleSessionSelect(sessionId);
    }
  };

  // Session selection handler
  const handleSessionSelect = async (sessionId: string) => {
    const sessionData = await sessionManager.loadSession(sessionId);
    if (sessionData && (sessionData.userInput || sessionData.generatedDescription)) {
      // Update listing generator state with session data
      listingGeneratorState.setUserInput(sessionData.userInput);
      listingGeneratorState.setPropertyType(sessionData.propertyType as any);
      listingGeneratorState.setGeneratedResponse(sessionData.generatedDescription);
      listingGeneratorState.setPhotoAnalyses(sessionData.photoAnalyses);
      if (sessionData.propertyStory) {
        // Create a PropertyStoryWithMLS object from the saved story string
        listingGeneratorState.setPropertyStory({
          mlsDescription: sessionData.propertyStory,
          storyText: sessionData.propertyStory,
        } as any);
      }
    } else {
      // For new/empty sessions, reset the generator to show blank state
      await listingGeneratorState.resetBuilder();
      setShowOutputScreen(false);
    }
  };

  return (
    <SidebarProvider defaultOpen={true}>
      <div className="min-h-screen w-full flex">
        <AppSidebar
          sessions={sessionManager.sessions}
          currentSessionId={sessionManager.currentSessionId}
          onSessionSelect={handleSessionSelect}
          onNewSession={handleNewSession}
          
          isLoading={sessionManager.isLoading}
        />
        
        <div className="flex-1 flex flex-col min-h-screen">
          <header className="bg-background/95 backdrop-blur-sm border-b border-border/20 z-40 sticky top-0 h-16 flex-shrink-0">
            <div className="flex items-center justify-between px-4 h-full">
              <div className="flex items-center gap-2">
                <SidebarTrigger className="hover:bg-accent" />
                {showOutputScreen ? (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setShowOutputScreen(false)}
                    className="mr-2"
                  >
                    Back to Input
                  </Button>
                ) : (
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={handleNewSession}
                    className="hover:bg-accent"
                    title="Add New Session"
                  >
                    <Plus className="h-4 w-4" />
                  </Button>
                )}
                <AppHeader />
              </div>
            </div>
          </header>
          <main className="flex-1 overflow-hidden">
            <ListingWorkspace
              {...listingGeneratorState}
              showOutputScreen={showOutputScreen}
              onStartOutputScreen={() => setShowOutputScreen(true)}
            />
          </main>
        </div>
      </div>
    </SidebarProvider>
  );
};

export default ListingGenerator;