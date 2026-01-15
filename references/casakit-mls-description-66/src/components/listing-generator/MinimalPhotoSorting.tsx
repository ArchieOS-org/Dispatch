/**
 * MinimalPhotoSorting: Drag-and-drop photo ordering interface
 * 
 * Allows users to reorder uploaded photos for optimal presentation sequence.
 * Provides visual feedback during drag operations and maintains sort order
 * for the final property listing generation.
 */

import React, { useState } from 'react';
import { DragDropContext, Droppable, Draggable, DropResult } from '@hello-pangea/dnd';
import { X, ChevronLeft, ChevronRight } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent } from "@/components/ui/dialog";
import type { PhotoInfo } from './types';

interface MinimalPhotoSortingProps {
  photos: PhotoInfo[];
  onReorder: (photos: PhotoInfo[]) => void;
  className?: string;
  showPlaceholders?: boolean;
}

export const MinimalPhotoSorting: React.FC<MinimalPhotoSortingProps> = ({
  photos,
  onReorder,
  className = "",
  showPlaceholders = false
}) => {
  const [isDragging, setIsDragging] = useState(false);
  const [viewingPhoto, setViewingPhoto] = useState<number | null>(null);

  const handleDragStart = () => {
    setIsDragging(true);
  };

  const handleDragEnd = (result: DropResult) => {
    setIsDragging(false);
    
    if (!result.destination) return;

    const startIndex = result.source.index;
    const endIndex = result.destination.index;

    if (startIndex === endIndex) return;

    // Only process drag if we have photos and both positions involve photos
    const startItem = draggableItems[startIndex];
    const endItem = draggableItems[endIndex];
    
    // Only allow reordering actual photos
    if (startItem?.type !== 'photo') return;

    // If destination is a placeholder, just move the photo to that position
    // If destination is another photo, swap them
    const reorderedPhotos = Array.from(photos);
    
    // Find the photo being moved
    const movedPhotoIndex = reorderedPhotos.findIndex(p => p.id === startItem.photo.id);
    if (movedPhotoIndex === -1) return;
    
    const [movedPhoto] = reorderedPhotos.splice(movedPhotoIndex, 1);
    
    // Calculate new position in photos array
    let photosBeforeEnd = draggableItems
      .slice(0, endIndex)
      .filter(item => item.type === 'photo')
      .length;

    // If dragging forward, the moved photo is included in photosBeforeEnd; adjust back by 1
    if (startIndex < endIndex) {
      photosBeforeEnd = Math.max(0, photosBeforeEnd - 1);
    }

    const insertIndex = Math.min(photosBeforeEnd, reorderedPhotos.length);
    
    reorderedPhotos.splice(insertIndex, 0, movedPhoto);

    // Update sort order
    const updatedPhotos = reorderedPhotos.map((photo, index) => ({
      ...photo,
      sortOrder: index
    }));

    onReorder(updatedPhotos);
  };

  const handlePhotoClick = (index: number, e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setViewingPhoto(index);
  };

  const handlePrevPhoto = () => {
    if (viewingPhoto !== null && viewingPhoto > 0) {
      setViewingPhoto(viewingPhoto - 1);
    }
  };

  const handleNextPhoto = () => {
    if (viewingPhoto !== null && viewingPhoto < photos.length - 1) {
      setViewingPhoto(viewingPhoto + 1);
    }
  };

  // Create unified draggable items (photos + placeholders)
  const totalSlots = Math.max(photos.length, showPlaceholders ? 25 : 0);
  const draggableItems = Array.from({ length: totalSlots }, (_, index) => {
    const photo = photos[index];
    return photo 
      ? { type: 'photo' as const, photo, index }
      : { type: 'placeholder' as const, id: `placeholder-${index}`, index };
  });

  // Show section when there are photos or when placeholders should be shown
  if (draggableItems.length === 0) return null;

  return (
    <div className={`space-y-3 ${className}`}>
      <div className="flex items-center justify-between">
        <p className="text-xs text-muted-foreground">
          {photos.length > 0 ? 'Drag to reorder' : 'Upload photos to fill these slots'}
        </p>
      </div>

      <DragDropContext onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
        <Droppable droppableId="photo-slots" direction="horizontal">
          {(provided, snapshot) => (
            <div
              ref={provided.innerRef}
              {...provided.droppableProps}
              className={`
                grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3
                transition-all duration-200
                ${snapshot.isDraggingOver ? 'opacity-90' : ''}
                ${isDragging ? 'cursor-grabbing' : ''}
              `}
            >
              {draggableItems.map((item, index) => (
                <Draggable 
                  key={item.type === 'photo' ? item.photo.id : item.id} 
                  draggableId={item.type === 'photo' ? item.photo.id : item.id} 
                  index={index}
                >
                  {(provided, snapshot) => (
                    <div
                      ref={provided.innerRef}
                      {...provided.draggableProps}
                      {...provided.dragHandleProps}
                      className={`
                        relative group cursor-pointer
                        transition-all duration-200 ease-out
                        ${snapshot.isDragging ? 
                          'rotate-3 scale-105 shadow-xl z-10 cursor-grabbing' : 
                          'hover:shadow-md hover:scale-102'
                        }
                      `}
                       onClick={item.type === 'photo' ? (e) => {
                         const photoIndex = photos.findIndex(p => p.id === item.photo.id);
                         if (photoIndex !== -1) handlePhotoClick(photoIndex, e);
                       } : undefined}
                    >
                      {item.type === 'photo' ? (
                        // Photo slot
                        <div className="relative aspect-square overflow-hidden rounded-lg bg-muted">
                          <img
                            src={item.photo.url}
                            alt={`Photo ${index + 1}`}
                            className="h-full w-full object-cover transition-transform duration-200"
                            loading="lazy"
                          />
                          
                          {/* Hover overlay */}
                          <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors duration-200" />
                          
                          {/* Room type badge */}
                          {(item.photo.analysis || item.photo.roomType) && (
                            <div className="absolute bottom-2 left-2 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                              <Badge 
                                variant="secondary" 
                                className="text-xs bg-background/80 backdrop-blur-sm"
                              >
                                {item.photo.analysis || item.photo.roomType || 'Photo'}
                              </Badge>
                            </div>
                          )}

                          {/* Sort order indicator (actual photo order) */}
                          <div className="absolute top-2 left-2 bg-primary text-primary-foreground text-xs font-medium rounded-full h-6 w-6 flex items-center justify-center">
                            {photos.findIndex(p => p.id === item.photo.id) + 1}
                          </div>
                        </div>
                      ) : (
                        // Placeholder slot
                        <div className={`
                          relative aspect-square border-2 border-dashed rounded-lg bg-muted/50 flex items-center justify-center
                          transition-all duration-200
                          ${snapshot.isDragging 
                            ? 'border-primary bg-primary/10 scale-105' 
                            : 'border-muted-foreground/30 hover:border-muted-foreground/50 hover:bg-muted/70'
                          }
                        `}>
                          <div className="text-center">
                            <div className="text-xs font-medium text-muted-foreground mb-1">
                              {index + 1}
                            </div>
                            <div className="text-xs text-muted-foreground/70">
                              Photo
                            </div>
                          </div>
                          
                          {/* Drag indicator */}
                          <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                            <div className="text-muted-foreground/50 text-xs">⋮⋮</div>
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                </Draggable>
              ))}
              {provided.placeholder}
            </div>
          )}
        </Droppable>
      </DragDropContext>

      {/* Photo Viewer Modal */}
      <Dialog open={viewingPhoto !== null} onOpenChange={() => setViewingPhoto(null)}>
        <DialogContent className="max-w-4xl max-h-[90vh] p-0 bg-black/95 border-none">
          {viewingPhoto !== null && (
            <div className="relative w-full h-full flex items-center justify-center">
              {/* Close Button */}
              <button
                onClick={() => setViewingPhoto(null)}
                className="absolute top-4 right-4 z-10 bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full p-2 transition-colors"
              >
                <X className="h-5 w-5 text-white" />
              </button>

              {/* Navigation Buttons */}
              {viewingPhoto > 0 && (
                <button
                  onClick={(e) => { e.stopPropagation(); handlePrevPhoto(); }}
                  className="absolute left-4 top-1/2 -translate-y-1/2 z-10 bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full p-3 transition-colors"
                >
                  <ChevronLeft className="h-6 w-6 text-white" />
                </button>
              )}
              
              {viewingPhoto < photos.length - 1 && (
                <button
                  onClick={(e) => { e.stopPropagation(); handleNextPhoto(); }}
                  className="absolute right-4 top-1/2 -translate-y-1/2 z-10 bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full p-3 transition-colors"
                >
                  <ChevronRight className="h-6 w-6 text-white" />
                </button>
              )}

              {/* Photo */}
              <img
                src={photos[viewingPhoto].url}
                alt={`Photo ${viewingPhoto + 1}`}
                className="max-w-full max-h-full object-contain"
              />

              {/* Photo Info */}
              <div className="absolute bottom-4 left-4 bg-white/20 backdrop-blur-sm rounded-lg p-3">
                <div className="text-white text-sm">
                  Photo {viewingPhoto + 1} of {photos.length}
                  {(photos[viewingPhoto].analysis || photos[viewingPhoto].roomType) && (
                    <span className="ml-2 text-white/80">
                      • {photos[viewingPhoto].analysis || photos[viewingPhoto].roomType}
                    </span>
                  )}
                </div>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
};