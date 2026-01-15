import { useState, useEffect } from 'react';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { useToast } from "@/hooks/use-toast";
import { useAuth } from "@/components/auth/AuthContext";
import { GoogleSignIn } from "@/components/auth/GoogleSignIn";
import { googleApi, GoogleForm, GoogleDriveFile, GoogleSheet } from "@/services/googleApi";
import { 
  ExternalLink, 
  FileText, 
  Folder, 
  Download, 
  CheckCircle2, 
  Star,
  Clock,
  Users,
  Loader2,
  Sheet
} from "lucide-react";

interface GoogleFormsIntegrationProps {
  onImportData?: (data: any) => void;
  isOpen?: boolean;
  onOpenChange?: (open: boolean) => void;
}


export const GoogleFormsIntegration = ({ onImportData, isOpen: externalIsOpen, onOpenChange: externalOnOpenChange }: GoogleFormsIntegrationProps) => {
  const [internalIsDialogOpen, setInternalIsDialogOpen] = useState(false);
  const isDialogOpen = externalIsOpen !== undefined ? externalIsOpen : internalIsDialogOpen;
  const setIsDialogOpen = externalOnOpenChange || setInternalIsDialogOpen;
  const [selectedView, setSelectedView] = useState<'forms' | 'drive' | 'sheets'>('forms');
  const [isImporting, setIsImporting] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [forms, setForms] = useState<GoogleForm[]>([]);
  const [driveFiles, setDriveFiles] = useState<GoogleDriveFile[]>([]);
  const [sheets, setSheets] = useState<GoogleSheet[]>([]);
  const { user, signOut } = useAuth();
  const { toast } = useToast();

  useEffect(() => {
    if (user && isDialogOpen) {
      loadGoogleData();
    }
  }, [user, isDialogOpen, selectedView]);

  const loadGoogleData = async () => {
    if (!user) return;
    
    setIsLoading(true);
    try {
      switch (selectedView) {
        case 'forms':
          const formsData = await googleApi.getForms();
          setForms(formsData);
          break;
        case 'drive':
          const filesData = await googleApi.getDriveFiles();
          setDriveFiles(filesData);
          break;
        case 'sheets':
          const sheetsData = await googleApi.getSheets();
          setSheets(sheetsData);
          break;
      }
    } catch (error) {
      toast({
        title: "Failed to load data",
        description: error instanceof Error ? error.message : "Failed to load Google data",
        variant: "destructive"
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleImportForm = async (formId: string) => {
    setIsImporting(true);
    try {
      const responses = await googleApi.getFormResponses(formId);
      
      // Parse form responses to extract property data
      const propertyData = parseFormData(responses);
      
      if (onImportData) {
        onImportData(propertyData);
      }
      
      setIsDialogOpen(false);
      toast({
        title: "Form Data Imported",
        description: "Property information has been successfully imported from Google Forms",
      });
    } catch (error) {
      toast({
        title: "Import Failed",
        description: error instanceof Error ? error.message : "Failed to import form data",
        variant: "destructive"
      });
    } finally {
      setIsImporting(false);
    }
  };

  const handleImportFile = async (fileId: string, fileName: string) => {
    setIsImporting(true);
    try {
      // For now, we'll just simulate file import
      // In a real implementation, you'd download and process the file
      
      if (onImportData) {
        onImportData({
          importedFile: fileName,
          fileId: fileId,
          importType: 'drive'
        });
      }
      
      toast({
        title: "File Imported",
        description: `${fileName} has been successfully imported from Google Drive`,
      });
    } catch (error) {
      toast({
        title: "Import Failed",
        description: error instanceof Error ? error.message : "Failed to import file",
        variant: "destructive"
      });
    } finally {
      setIsImporting(false);
    }
  };

  const handleImportSheet = async (sheetId: string, sheetName: string) => {
    setIsImporting(true);
    try {
      const data = await googleApi.getSheetData(sheetId);
      const propertyData = parseSheetData(data);
      
      if (onImportData) {
        onImportData(propertyData);
      }
      
      setIsDialogOpen(false);
      toast({
        title: "Sheet Data Imported",
        description: `Property data from ${sheetName} has been successfully imported`,
      });
    } catch (error) {
      toast({
        title: "Import Failed",
        description: error instanceof Error ? error.message : "Failed to import sheet data",
        variant: "destructive"
      });
    } finally {
      setIsImporting(false);
    }
  };

  const parseFormData = (responses: any[]) => {
    // This is a simplified parser - in a real implementation,
    // you'd analyze the form structure and map responses to property fields
    if (!responses.length) return {};
    
    return {
      propertyInfo: "Data imported from Google Form",
      importType: 'form',
      responses: responses.length
    };
  };

  const parseSheetData = (data: any[][]) => {
    // This is a simplified parser - in a real implementation,
    // you'd analyze column headers and map data to property fields
    if (!data.length) return {};
    
    const headers = data[0] || [];
    const rows = data.slice(1);
    
    return {
      propertyInfo: "Data imported from Google Sheet",
      importType: 'sheet',
      headers,
      rowCount: rows.length
    };
  };

  if (!user) {
    return (
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>        
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Connect Google Account</DialogTitle>
          </DialogHeader>
          <GoogleSignIn />
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>      
      <DialogContent className="max-w-4xl max-h-[80vh] overflow-hidden">
        <DialogHeader>
          <DialogTitle className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex -space-x-0.5">
                <div className="w-4 h-4 bg-[hsl(207_100%_50%)] rounded-full"></div>
                <div className="w-4 h-4 bg-[hsl(4_100%_59%)] rounded-full"></div>
                <div className="w-4 h-4 bg-[hsl(45_100%_51%)] rounded-full"></div>
                <div className="w-4 h-4 bg-[hsl(134_71%_49%)] rounded-full"></div>
              </div>
              Google Workspace Integration
            </div>
            <Button variant="ghost" size="sm" onClick={signOut}>
              Sign Out
            </Button>
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          {/* Tab-like navigation */}
          <div className="flex gap-2 border-b">
            <Button
              variant={selectedView === 'forms' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setSelectedView('forms')}
              className="flex items-center gap-2"
            >
              <FileText className="h-4 w-4" />
              Google Forms
            </Button>
            <Button
              variant={selectedView === 'drive' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setSelectedView('drive')}
              className="flex items-center gap-2"
            >
              <Folder className="h-4 w-4" />
              Google Drive
            </Button>
            <Button
              variant={selectedView === 'sheets' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setSelectedView('sheets')}
              className="flex items-center gap-2"
            >
              <Sheet className="h-4 w-4" />
              Google Sheets
            </Button>
          </div>

          <div className="overflow-y-auto max-h-[50vh]">
            {isLoading ? (
              <div className="flex items-center justify-center py-8">
                <Loader2 className="h-6 w-6 animate-spin" />
                <span className="ml-2">Loading...</span>
              </div>
            ) : (
              <>
                {selectedView === 'forms' && (
                  <div className="space-y-4">
                    <div className="text-sm text-muted-foreground">
                      Select a Google Form to import property listing data
                    </div>
                    {forms.length === 0 ? (
                      <div className="text-center py-6 text-muted-foreground">
                        No forms found. Create a form in Google Forms first.
                      </div>
                    ) : (
                      <div className="grid gap-3">
                        {forms.map((form) => (
                          <Card key={form.id} className="hover:shadow-md transition-shadow cursor-pointer">
                            <CardContent className="p-4">
                              <div className="flex items-start justify-between">
                                <div className="flex-1 space-y-2">
                                  <div className="flex items-center gap-2">
                                    <h4 className="font-medium">{form.title}</h4>
                                  </div>
                                  <p className="text-sm text-muted-foreground">{form.description}</p>
                                  <div className="flex items-center gap-4 text-xs text-muted-foreground">
                                    <div className="flex items-center gap-1">
                                      <Clock className="h-3 w-3" />
                                      {new Date(form.lastModified).toLocaleDateString()}
                                    </div>
                                  </div>
                                </div>
                                <Button
                                  size="sm"
                                  onClick={() => handleImportForm(form.id)}
                                  disabled={isImporting}
                                  className="ml-4"
                                >
                                  {isImporting ? (
                                    <Loader2 className="h-4 w-4 animate-spin" />
                                  ) : (
                                    <>
                                      <Download className="h-4 w-4 mr-1" />
                                      Import
                                    </>
                                  )}
                                </Button>
                              </div>
                            </CardContent>
                          </Card>
                        ))}
                      </div>
                    )}
                  </div>
                )}

                {selectedView === 'drive' && (
                  <div className="space-y-4">
                    <div className="text-sm text-muted-foreground">
                      Select files from Google Drive to import
                    </div>
                    {driveFiles.length === 0 ? (
                      <div className="text-center py-6 text-muted-foreground">
                        No relevant files found in Google Drive.
                      </div>
                    ) : (
                      <div className="grid gap-2">
                        {driveFiles.map((file) => (
                          <div 
                            key={file.id} 
                            className="flex items-center justify-between p-3 border rounded-lg hover:bg-muted/50 transition-colors"
                          >
                            <div className="flex items-center gap-3">
                              <FileText className="h-5 w-5 text-muted-foreground" />
                              <div>
                                <div className="font-medium text-sm">{file.name}</div>
                                <div className="text-xs text-muted-foreground">
                                  {file.size} • Modified {new Date(file.modifiedTime).toLocaleDateString()}
                                </div>
                              </div>
                            </div>
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleImportFile(file.id, file.name)}
                              disabled={isImporting}
                            >
                              {isImporting ? (
                                <Loader2 className="h-4 w-4 animate-spin" />
                              ) : (
                                <>
                                  <Download className="h-4 w-4 mr-1" />
                                  Import
                                </>
                              )}
                            </Button>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}

                {selectedView === 'sheets' && (
                  <div className="space-y-4">
                    <div className="text-sm text-muted-foreground">
                      Select a Google Sheet to import property data
                    </div>
                    {sheets.length === 0 ? (
                      <div className="text-center py-6 text-muted-foreground">
                        No spreadsheets found in Google Drive.
                      </div>
                    ) : (
                      <div className="grid gap-3">
                        {sheets.map((sheet) => (
                          <Card key={sheet.id} className="hover:shadow-md transition-shadow cursor-pointer">
                            <CardContent className="p-4">
                              <div className="flex items-start justify-between">
                                <div className="flex-1 space-y-2">
                                  <h4 className="font-medium">{sheet.name}</h4>
                                  <div className="text-xs text-muted-foreground">
                                    {sheet.sheets.length} sheet{sheet.sheets.length !== 1 ? 's' : ''}
                                  </div>
                                </div>
                                <Button
                                  size="sm"
                                  onClick={() => handleImportSheet(sheet.id, sheet.name)}
                                  disabled={isImporting}
                                  className="ml-4"
                                >
                                  {isImporting ? (
                                    <Loader2 className="h-4 w-4 animate-spin" />
                                  ) : (
                                    <>
                                      <Download className="h-4 w-4 mr-1" />
                                      Import
                                    </>
                                  )}
                                </Button>
                              </div>
                            </CardContent>
                          </Card>
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </>
            )}
          </div>

          <div className="flex items-center gap-2 text-xs text-muted-foreground bg-muted/30 p-3 rounded-lg">
            <CheckCircle2 className="h-4 w-4 text-accent" />
            Connected to {user.email} • Secure access via OAuth 2.0
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};