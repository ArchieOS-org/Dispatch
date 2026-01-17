import { useState } from "react";
import { usePromptBuilder } from "./usePromptBuilder";
import { useSessionManager } from "./useSessionManager";
import { HomeScreen } from "./HomeScreen";
import { AppSidebar } from "../layout/AppSidebar";
import { AppHeader } from "./AppHeader";
import { SidebarProvider, SidebarTrigger } from "@/components/ui/sidebar";
import { Button } from "@/components/ui/button";
import { Plus } from "lucide-react";

const PromptBuilder = () => {
  const sessionManager = useSessionManager();
  const promptBuilderState = usePromptBuilder(sessionManager);

  // Handle new session creation
  const handleNewSession = async () => {
    const sessionId = await sessionManager.createSession();
    if (sessionId) {
      await handleSessionSelect(sessionId);
    }
  };

  // Session selection handler
  const handleSessionSelect = async (sessionId: string) => {
    const sessionData = await sessionManager.loadSession(sessionId);
    if (sessionData && (sessionData.userInput || sessionData.generatedDescription)) {
      // Update prompt builder state with session data
      promptBuilderState.setUserInput(sessionData.userInput);
      promptBuilderState.setPropertyType(sessionData.propertyType as any);
      promptBuilderState.setGeneratedResponse(sessionData.generatedDescription);
      promptBuilderState.setPhotoAnalyses(sessionData.photoAnalyses);
      if (sessionData.propertyStory) {
        // Create a PropertyStoryWithMLS object from the saved story string
        promptBuilderState.setPropertyStory({
          mlsDescription: sessionData.propertyStory,
          storyText: sessionData.propertyStory,
        } as any);
      }
    } else {
      // For new/empty sessions, reset the builder to show blank state
      await promptBuilderState.resetBuilder();
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
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={handleNewSession}
                  className="hover:bg-accent"
                  title="Add New Session"
                >
                  <Plus className="h-4 w-4" />
                </Button>
                <AppHeader />
              </div>
            </div>
          </header>
          <main className="flex-1 overflow-hidden">
            <HomeScreen {...promptBuilderState} />
          </main>
        </div>
      </div>
    </SidebarProvider>
  );
};

export default PromptBuilder;