import { useState } from "react";
import { Cloud } from "lucide-react";
import { GoogleFormsIntegration } from "./GoogleFormsIntegration";

interface GoogleImportButtonProps {
  onPropertyDataImport?: (data: any) => void;
}

export const GoogleImportButton = ({ onPropertyDataImport }: GoogleImportButtonProps) => {
  const [isDialogOpen, setIsDialogOpen] = useState(false);

  return (
    <>
      <div 
        onClick={() => setIsDialogOpen(true)}
        className="h-32 rounded-lg border border-input bg-background hover:bg-muted/40 hover:shadow-sm transition-all duration-200 ease-out flex items-center justify-center cursor-pointer"
      >
        <div className="text-center space-y-2">
          <div className="w-10 h-10 mx-auto rounded-full bg-muted/50 flex items-center justify-center">
            <Cloud className="w-5 h-5 text-muted-foreground" />
          </div>
          <div>
            <p className="text-sm font-medium text-foreground">Property listing form</p>
          </div>
        </div>
      </div>
      <GoogleFormsIntegration 
        onImportData={onPropertyDataImport} 
        isOpen={isDialogOpen}
        onOpenChange={setIsDialogOpen}
      />
    </>
  );
};