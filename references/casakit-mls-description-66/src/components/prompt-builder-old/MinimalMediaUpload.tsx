/**
 * MinimalMediaUpload: Simplified media upload interface for mobile-first design
 * 
 * Streamlined version of the full media upload component, optimized for the
 * single-screen app layout. Handles photos, documents, and floorplans with
 * clean, minimal interface focused on ease of use.
 */

import { useState, useCallback } from 'react';
import { useToast } from "@/hooks/use-toast";
import { FileImage, FileText, X, Plus } from "lucide-react";
import type { MediaInfo } from "./types";

interface MinimalMediaUploadProps {
  media: MediaInfo[];
  onMediaChange: (media: MediaInfo[]) => void;
  maxFiles?: number;
}

const getFileTypeFromFile = (file: File): 'photo' | 'document' | 'floorplan' => {
  if (file.type.startsWith('image/')) {
    if (file.name.toLowerCase().includes('floor') || file.name.toLowerCase().includes('plan')) {
      return 'floorplan';
    }
    return 'photo';
  }
  return 'document';
};

export const MinimalMediaUpload = ({ media, onMediaChange, maxFiles = 100 }: MinimalMediaUploadProps) => {
  const [dragOver, setDragOver] = useState(false);
  const { toast } = useToast();

  const handleFileUpload = useCallback(async (files: FileList) => {
    const newFiles = Array.from(files);
    
    if (media.length + newFiles.length > maxFiles) {
      toast({
        title: "Too many files",
        description: `Maximum ${maxFiles} files allowed`,
        variant: "destructive"
      });
      return;
    }

    const validFiles = newFiles.filter(file => {
      const maxSize = file.type.startsWith('image/') ? 10 * 1024 * 1024 : 50 * 1024 * 1024;
      if (file.size > maxSize) {
        toast({
          title: "File too large",
          description: `${file.name} is larger than ${maxSize / (1024 * 1024)}MB`,
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
      type: getFileTypeFromFile(file),
      category: 'other',
      sortOrder: media.length
    }));

    onMediaChange([...media, ...newMedia]);
    
    if (validFiles.length > 0) {
      toast({
        title: "Files Added",
        description: `${validFiles.length} file${validFiles.length > 1 ? 's' : ''} added`,
      });
    }
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

  const photos = media.filter(m => m.type === 'photo');
  const documents = media.filter(m => m.type === 'document');
  const floorplans = media.filter(m => m.type === 'floorplan');

  return (
    <div className="space-y-8">
      {/* Upload Zone */}
      <div
        className={`
          relative rounded-lg transition-all duration-200 ease-out
          ${dragOver 
            ? 'bg-primary/5 border-2 border-dashed border-primary/20' 
            : 'bg-background hover:bg-muted/30 border border-transparent'
          }
        `}
        onDrop={handleDrop}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
      >
        <div className="p-8 text-center space-y-4">
          <div className="w-12 h-12 mx-auto rounded-full bg-muted/50 flex items-center justify-center">
            <Plus className="w-5 h-5 text-muted-foreground" />
          </div>
          <div className="space-y-1">
            <p className="text-sm font-medium text-foreground">Add photos and documents</p>
            <p className="text-xs text-muted-foreground">Drop files here or click to browse</p>
          </div>
          <label className="cursor-pointer inline-block">
            <span className="text-xs text-primary hover:text-primary/80 transition-colors">
              Choose files
            </span>
            <input
              type="file"
              multiple
              accept="image/*,.pdf,.doc,.docx,.txt"
              className="hidden"
              onChange={(e) => e.target.files && handleFileUpload(e.target.files)}
            />
          </label>
        </div>
      </div>

      {/* Photos Section */}
      {photos.length > 0 && (
        <div className="space-y-4">
          <h4 className="text-sm font-medium text-foreground">Property Photos</h4>
          <div className="grid grid-cols-4 sm:grid-cols-6 lg:grid-cols-8 gap-3">
            {photos.map((file) => (
              <div key={file.id} className="relative group aspect-square">
                <img
                  src={file.url}
                  alt="Property"
                  className="w-full h-full object-cover rounded-md transition-transform group-hover:scale-[1.02]"
                />
                <button
                  onClick={() => removeFile(file.id)}
                  className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-background border shadow-sm flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
                  aria-label="Remove photo"
                >
                  <X className="w-3 h-3" />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Documents Section */}
      {(documents.length > 0 || floorplans.length > 0) && (
        <div className="space-y-4">
          <h4 className="text-sm font-medium text-foreground">Documents & Plans</h4>
          <div className="space-y-2">
            {[...documents, ...floorplans].map((file) => (
              <div key={file.id} className="group flex items-center gap-3 p-3 rounded-md hover:bg-muted/30 transition-colors">
                <div className="w-8 h-8 rounded bg-muted/50 flex items-center justify-center flex-shrink-0">
                  {file.type === 'floorplan' ? (
                    <FileImage className="w-4 h-4 text-muted-foreground" />
                  ) : (
                    <FileText className="w-4 h-4 text-muted-foreground" />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium truncate">{file.file.name}</p>
                  <p className="text-xs text-muted-foreground">
                    {file.type === 'floorplan' ? 'Floor Plan' : 'Document'} • {(file.file.size / 1024 / 1024).toFixed(1)}MB
                  </p>
                </div>
                <button
                  onClick={() => removeFile(file.id)}
                  className="w-6 h-6 rounded flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity hover:bg-destructive/10"
                  aria-label="Remove file"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* File Count */}
      {media.length > 0 && (
        <div className="text-center">
          <p className="text-xs text-muted-foreground">
            {media.length} file{media.length !== 1 ? 's' : ''} • {photos.length} photo{photos.length !== 1 ? 's' : ''}
            {documents.length + floorplans.length > 0 && ` • ${documents.length + floorplans.length} document${documents.length + floorplans.length !== 1 ? 's' : ''}`}
          </p>
        </div>
      )}
    </div>
  );
};