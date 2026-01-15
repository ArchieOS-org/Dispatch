import { formatDistanceToNow } from 'date-fns';
import { MessageSquare, MoreVertical, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { cn } from '@/lib/utils';
import type { Session } from '@/services/backend';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

interface SessionsListProps {
  sessions: Session[];
  currentSessionId: string | null;
  onSessionSelect: (sessionId: string) => void;
  isLoading: boolean;
  onDeleteSession: (sessionId: string) => Promise<void>;
}

export const SessionsList = ({ 
  sessions, 
  currentSessionId, 
  onSessionSelect, 
  isLoading,
  onDeleteSession
}: SessionsListProps) => {

  // Group sessions by time periods
  const groupSessionsByTime = (sessions: Session[]) => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
    const weekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);

    const groups = {
      today: [] as Session[],
      yesterday: [] as Session[],
      thisWeek: [] as Session[],
      older: [] as Session[],
    };

    sessions.forEach(session => {
      const sessionDate = new Date(session.last_accessed_at);
      if (sessionDate >= today) {
        groups.today.push(session);
      } else if (sessionDate >= yesterday) {
        groups.yesterday.push(session);
      } else if (sessionDate >= weekAgo) {
        groups.thisWeek.push(session);
      } else {
        groups.older.push(session);
      }
    });

    return groups;
  };

  const groupedSessions = groupSessionsByTime(sessions);

  const handleDelete = async (sessionId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    await onDeleteSession(sessionId);
  };

  const SessionItem = ({ session }: { session: Session }) => (
    <div
      onClick={() => onSessionSelect(session.id)}
      className={cn(
        "group flex items-center justify-between p-3 rounded-lg cursor-pointer transition-all duration-200",
        "hover:bg-accent/50 border border-transparent hover:border-border/20",
        currentSessionId === session.id 
          ? "bg-primary/10 border-primary/20 text-primary" 
          : "text-foreground"
      )}
    >
      <div className="flex items-center gap-3 flex-1 min-w-0">
        <MessageSquare className="h-4 w-4 flex-shrink-0 opacity-60" />
        <div className="flex-1 min-w-0">
          <div className="font-medium truncate text-sm">
            {session.name}
          </div>
          <div className="text-xs text-muted-foreground">
            {formatDistanceToNow(new Date(session.last_accessed_at), { addSuffix: true })}
          </div>
        </div>
      </div>
      
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="ghost"
            size="sm"
            className="h-8 w-8 p-0 opacity-0 group-hover:opacity-100 transition-opacity"
          >
            <MoreVertical className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem
            onClick={(e) => handleDelete(session.id, e)}
            className="text-destructive focus:text-destructive"
          >
            <Trash2 className="h-4 w-4 mr-2" />
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );

  const GroupSection = ({ title, sessions }: { title: string; sessions: Session[] }) => {
    if (sessions.length === 0) return null;

    return (
      <div className="mb-6">
        <h3 className="text-xs font-medium text-muted-foreground mb-2 px-3 uppercase tracking-wider">
          {title}
        </h3>
        <div className="space-y-1 px-3">
          {sessions.map(session => (
            <SessionItem key={session.id} session={session} />
          ))}
        </div>
      </div>
    );
  };

  if (isLoading && sessions.length === 0) {
    return (
      <div className="flex items-center justify-center h-32 text-muted-foreground">
        <MessageSquare className="h-8 w-8 opacity-50" />
      </div>
    );
  }

  if (sessions.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-32 text-center p-4">
        <MessageSquare className="h-8 w-8 text-muted-foreground mb-2" />
        <p className="text-sm text-muted-foreground">No sessions yet</p>
        <p className="text-xs text-muted-foreground/70">Create your first session to get started</p>
      </div>
    );
  }

  return (
    <ScrollArea className="h-full">
      <div className="py-2">
        <GroupSection title="Today" sessions={groupedSessions.today} />
        <GroupSection title="Yesterday" sessions={groupedSessions.yesterday} />
        <GroupSection title="This Week" sessions={groupedSessions.thisWeek} />
        <GroupSection title="Older" sessions={groupedSessions.older} />
      </div>
    </ScrollArea>
  );
};