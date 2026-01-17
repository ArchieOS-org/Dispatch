import { useState } from "react";
import { Plus, User, LogOut } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar";
import { ScrollArea } from "@/components/ui/scroll-area";
import { useAuth } from "@/components/auth/AuthContext";
import { GoogleSignIn } from "@/components/auth/GoogleSignIn";
import { Badge } from "@/components/ui/badge";
import type { Session } from "@/services/backend";

interface AppSidebarProps {
  sessions: Session[];
  currentSessionId: string | null;
  onSessionSelect: (sessionId: string) => void;
  onNewSession: () => void;
  
  isLoading: boolean;
}

export function AppSidebar({
  sessions,
  currentSessionId,
  onSessionSelect,
  onNewSession,
  isLoading
}: AppSidebarProps) {
  const { user, signOut, isLoading: authLoading } = useAuth();
  const [showSignIn, setShowSignIn] = useState(false);
  
  const isActive = (sessionId: string) => currentSessionId === sessionId;

  const handleSignOut = async () => {
    try {
      await signOut();
    } catch (error) {
      console.error('Sign out error:', error);
    }
  };

  return (
    <Sidebar 
      collapsible="offcanvas"
      variant="sidebar"
    >
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel className="flex items-center justify-between px-2 py-3 text-foreground font-medium">
            <span className="px-2 group-data-[collapsible=icon]:hidden">Sessions</span>
            <Button
              onClick={onNewSession}
              disabled={isLoading}
              variant="ghost"
              size="sm"
              className="h-8 w-8 p-0 hover:bg-primary hover:text-primary-foreground transition-all duration-300 ease-smooth rounded-md group-data-[collapsible=icon]:mx-auto"
            >
              <Plus className="h-4 w-4" />
            </Button>
          </SidebarGroupLabel>

          <SidebarGroupContent className="px-2">
            <ScrollArea className="h-[calc(100vh-200px)]">
              <SidebarMenu className="space-y-1">
                {sessions.map((session) => (
                  <SidebarMenuItem key={session.id}>
                    <SidebarMenuButton
                      onClick={() => onSessionSelect(session.id)}
                      className={`
                        rounded-lg transition-all duration-300 ease-smooth
                        group-data-[collapsible=icon]:w-10 group-data-[collapsible=icon]:h-10 group-data-[collapsible=icon]:p-0 group-data-[collapsible=icon]:mx-auto
                        ${isActive(session.id)
                          ? "bg-secondary text-secondary-foreground shadow-sm"
                          : "hover:bg-accent/50 text-foreground"
                        }
                      `}
                    >
                      {/* Icon state - show first word */}
                      <span className="text-xs font-mono hidden group-data-[collapsible=icon]:inline">
                        {session.name.split(' ')[0]}
                      </span>
                      
                      {/* Full state - show complete session info */}
                      <div className="flex items-center gap-3 w-full text-left group-data-[collapsible=icon]:hidden">
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2">
                            <div className="font-medium text-sm truncate leading-tight">
                              {session.name}
                            </div>
                            {session.id.startsWith('demo-') && (
                              <Badge variant="secondary" className="text-xs px-1.5 py-0">
                                Demo
                              </Badge>
                            )}
                          </div>
                        </div>
                      </div>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                ))}
              </SidebarMenu>
            </ScrollArea>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>

      <SidebarFooter className="border-t border-border/20 p-4">
        {user ? (
          <div className="group-data-[collapsible=icon]:hidden">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 min-w-0 flex-1">
                <div className="flex items-center gap-2 px-3 py-1.5 bg-accent/50 rounded-full min-w-0 flex-1">
                  <User className="h-4 w-4 text-primary flex-shrink-0" />
                  <span className="text-sm font-medium text-foreground truncate">
                    {user.email?.split('@')[0]}
                  </span>
                </div>
              </div>
              <Button
                variant="ghost"
                size="sm"
                onClick={handleSignOut}
                className="text-muted-foreground hover:text-foreground ml-2 flex-shrink-0"
              >
                <LogOut className="h-4 w-4" />
              </Button>
            </div>
          </div>
        ) : (
          <div className="group-data-[collapsible=icon]:hidden">
            <div className="space-y-2">
              {showSignIn ? (
                <div className="space-y-2">
                  <GoogleSignIn />
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setShowSignIn(false)}
                    className="w-full text-muted-foreground"
                  >
                    Cancel
                  </Button>
                </div>
              ) : (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowSignIn(true)}
                  disabled={authLoading}
                  className="w-full bg-background/50 hover:bg-accent/80"
                >
                  <User className="h-4 w-4 mr-2" />
                  Sign In
                </Button>
              )}
            </div>
          </div>
        )}
        
        {/* Icon-only user button when collapsed */}
        <div className="hidden group-data-[collapsible=icon]:block">
          <Button
            variant="ghost"
            size="sm"
            onClick={user ? handleSignOut : () => setShowSignIn(true)}
            disabled={authLoading}
            className="h-10 w-10 p-0 mx-auto flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-accent/50"
          >
            <User className="h-4 w-4" />
          </Button>
        </div>
      </SidebarFooter>
    </Sidebar>
  );
}