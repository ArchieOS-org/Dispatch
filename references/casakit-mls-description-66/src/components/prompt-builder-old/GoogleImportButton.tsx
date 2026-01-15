
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { GoogleFormsIntegration } from "../listing-generator/GoogleFormsIntegration";
import { FileText, CheckCircle } from "lucide-react";

interface GoogleImportButtonProps {
  onPropertyDataImport: (data: any) => void;
}

export const GoogleImportButton = ({ onPropertyDataImport }: GoogleImportButtonProps) => {
  const [isDialogOpen, setIsDialogOpen] = useState(false);

  return (
    <>
      <Button
        variant="outline"
        onClick={() => setIsDialogOpen(true)}
        className="w-full h-12 flex items-center justify-center gap-2"
      >
        <FileText className="h-4 w-4" />
        Import from Google Forms
      </Button>
      <GoogleFormsIntegration 
        onImportData={onPropertyDataImport} 
        isOpen={isDialogOpen}
        onOpenChange={setIsDialogOpen}
      />
    </>
  );
};
