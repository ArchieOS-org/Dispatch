/**
 * FileUploadButton: Streamlined file upload component for property media
 * 
 * Handles upload of various file types including photos, documents, and floorplans.
 * Provides drag-and-drop functionality and file type validation.
 * Replaces the old DocumentUpload component with simplified interface.
 */

import { useState, useCallback, useRef, useEffect } from 'react';
import { useToast } from "@/hooks/use-toast";
import { FileText, Upload, X, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import type { MediaInfo } from "./types";

interface FileUploadButtonProps {
  media: MediaInfo[];
  onMediaChange: (media: MediaInfo[]) => void;
  maxFiles?: number;
}

export const FileUploadButton = ({ media, onMediaChange, maxFiles = 50 }: FileUploadButtonProps) => {
  const [dragOver, setDragOver] = useState(false);
  const { toast } = useToast();
  const scrollRef = useRef<HTMLDivElement>(null);

  const documents = media.filter(m => m.type === 'document' || m.type === 'floorplan');

  // Auto-scroll to bottom when new documents are added
  useEffect(() => {
    if (scrollRef.current && documents.length > 0) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [documents.length]);

  const handleFileUpload = useCallback(async (files: FileList) => {
    const newFiles = Array.from(files).filter(file => !file.type.startsWith('image/'));
    
    if (media.length + newFiles.length > maxFiles) {
      toast({
        title: "Too many files",
        description: `Maximum ${maxFiles} files allowed`,
        variant: "destructive"
      });
      return;
    }

    const validFiles = newFiles.filter(file => {
      const maxSize = 50 * 1024 * 1024; // 50MB for documents
      if (file.size > maxSize) {
        toast({
          title: "File too large",
          description: `${file.name} is larger than 50MB`,
          variant: "destructive"
        });
        return false;
      }
      return true;
    });

    const newMedia: MediaInfo[] = validFiles.map(file => ({
      id: crypto.randomUUID(),
      file,
      url: URL.createObjectURL(file),
      type: file.name.toLowerCase().includes('floor') || file.name.toLowerCase().includes('plan') ? 'floorplan' : 'document',
      category: 'other',
      sortOrder: media.length
    }));

    onMediaChange([...media, ...newMedia]);
  }, [media, maxFiles, onMediaChange, toast]);

  const removeFile = useCallback((fileId: string) => {
    const fileToRemove = media.find(m => m.id === fileId);
    if (fileToRemove) {
      URL.revokeObjectURL(fileToRemove.url);
    }
    onMediaChange(media.filter(m => m.id !== fileId));
  }, [media, onMediaChange]);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const files = e.dataTransfer.files;
    if (files.length > 0) {
      handleFileUpload(files);
    }
  }, [handleFileUpload]);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    if (!e.currentTarget.contains(e.relatedTarget as Node)) {
      setDragOver(false);
    }
  }, []);

  return (
    <label
      className={`
        relative rounded-lg transition-all duration-200 ease-out border h-32 flex cursor-pointer
        ${dragOver 
          ? 'bg-primary/5 border-primary/30' 
          : 'bg-background hover:bg-muted/40 hover:shadow-sm border-input'
        }
      `}
      onDrop={handleDrop}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
    >
      {documents.length === 0 ? (
        // Empty state - show upload UI
        <div className="w-full flex items-center justify-center">
          <div className="text-center space-y-2">
            <div className="w-10 h-10 mx-auto rounded-full bg-muted/50 flex items-center justify-center">
              <FileText className="w-5 h-5 text-muted-foreground" />
            </div>
            <div>
              <p className="text-sm font-medium text-foreground">MLS sheets, reports, plans</p>
            </div>
          </div>
        </div>
      ) : (
        // Documents uploaded - show scrollable list
        <div className="w-full p-3 flex flex-col h-full">
          <ScrollArea className="flex-1 pr-1">
            <div ref={scrollRef} className="space-y-2">
              {documents.map((file) => (
                <div key={file.id} className="group flex items-center gap-2 hover:bg-muted/20 rounded px-1 transition-colors">
                  <div className="w-4 h-4 rounded bg-muted/50 flex items-center justify-center flex-shrink-0">
                    <FileText className="w-2.5 h-2.5 text-muted-foreground" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium truncate">{file.file.name}</p>
                    <p className="text-xs text-muted-foreground">
                      {(file.file.size / 1024 / 1024).toFixed(1)}MB
                    </p>
                  </div>
                  <button
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      removeFile(file.id);
                    }}
                    className="w-4 h-4 rounded flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity hover:bg-destructive/10"
                    aria-label="Remove file"
                  >
                    <X className="w-2.5 h-2.5" />
                  </button>
                </div>
              ))}
              <div className="flex items-center gap-2 px-1 py-1 rounded border border-dashed border-muted-foreground/30 bg-muted/20 hover:bg-muted/40 transition-colors">
                <Plus className="w-3 h-3 text-muted-foreground" />
                <p className="text-xs text-muted-foreground">Add more</p>
              </div>
            </div>
          </ScrollArea>
        </div>
      )}
      <input
        type="file"
        multiple
        accept=".pdf,.doc,.docx,.txt,.rtf,.xls,.xlsx"
        className="hidden"
        onChange={(e) => e.target.files && handleFileUpload(e.target.files)}
      />
    </label>
  );
};