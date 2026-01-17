/**
 * PhotoUploadSection: Primary photo upload component for property listings
 * 
 * Handles photo upload with drag-and-drop support, file validation, and
 * preview generation. Integrates with the unified MediaInfo system for
 * consistent file management across the application.
 */

import { useState, useCallback, useRef, useEffect } from 'react';
import { useToast } from "@/hooks/use-toast";
import { Camera, Plus, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ScrollArea, ScrollBar } from "@/components/ui/scroll-area";
import type { MediaInfo } from "./types";
interface PhotoUploadSectionProps {
  media: MediaInfo[];
  onMediaChange: (media: MediaInfo[]) => void;
  maxFiles?: number;
}
export const PhotoUploadSection = ({
  media,
  onMediaChange,
  maxFiles = 50
}: PhotoUploadSectionProps) => {
  const [dragOver, setDragOver] = useState(false);
  const {
    toast
  } = useToast();
  const scrollRef = useRef<HTMLDivElement>(null);
  const photos = media.filter(m => m.type === 'photo');

  // Auto-scroll to bottom when new photos are added
  useEffect(() => {
    if (scrollRef.current && photos.length > 0) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [photos.length]);
  const handleFileUpload = useCallback(async (files: FileList) => {
    const newFiles = Array.from(files).filter(file => file.type.startsWith('image/'));
    if (media.length + newFiles.length > maxFiles) {
      toast({
        title: "Too many files",
        description: `Maximum ${maxFiles} files allowed`,
        variant: "destructive"
      });
      return;
    }
    const validFiles = newFiles.filter(file => {
      const maxSize = 10 * 1024 * 1024; // 10MB for images
      if (file.size > maxSize) {
        toast({
          title: "File too large",
          description: `${file.name} is larger than 10MB`,
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
      type: 'photo',
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
    <label className="cursor-pointer">
      <div 
        className={`
          relative rounded-lg transition-all duration-200 ease-out border h-32 flex
          ${dragOver ? 'bg-primary/5 border-primary/30' : 'bg-background hover:bg-muted/40 hover:shadow-sm border-input'}
        `}
        onDrop={handleDrop}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
      >
        {photos.length === 0 ? (
          // Empty state - show upload UI
          <div className="w-full flex items-center justify-center">
            <div className="text-center space-y-2">
              <div className="w-10 h-10 mx-auto rounded-full bg-muted/50 flex items-center justify-center">
                <Camera className="w-5 h-5 text-muted-foreground" />
              </div>
              <div>
                <p className="text-sm font-medium text-foreground">Property images</p>
              </div>
            </div>
          </div>
        ) : (
          // Photos uploaded - show vertical scroll with grid
          <div className="w-full p-2 h-full">
            <ScrollArea className="w-full h-full">
              <div ref={scrollRef} className="grid grid-cols-[repeat(auto-fit,minmax(56px,1fr))] gap-0.5 pb-2">
                {photos.map((file) => (
                  <div key={file.id} className="relative group w-14 h-14">
                    <img 
                      src={file.url} 
                      alt="Property" 
                      className="w-full h-full object-cover rounded-sm"
                    />
                    <button
                      onClick={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        removeFile(file.id);
                      }}
                      className="absolute -top-1 -right-1 w-3.5 h-3.5 rounded-full bg-background border shadow-sm flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
                      aria-label="Remove photo"
                    >
                      <X className="w-2 h-2" />
                    </button>
                  </div>
                ))}
                <div className="w-14 h-14 rounded-sm border border-dashed border-muted-foreground/40 bg-background/60 flex items-center justify-center hover:bg-muted/30 transition-colors">
                  <Plus className="w-3 h-3 text-muted-foreground" />
                </div>
              </div>
              <ScrollBar orientation="vertical" />
            </ScrollArea>
          </div>
        )}
      </div>
      <input 
        type="file" 
        multiple 
        accept="image/*" 
        className="hidden" 
        onChange={(e) => e.target.files && handleFileUpload(e.target.files)} 
      />
    </label>
  );
};