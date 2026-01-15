import { supabase } from '@/integrations/supabase/client';

export interface GoogleForm {
  id: string;
  title: string;
  description: string;
  responseCount?: number;
  lastModified: string;
}

export interface GoogleDriveFile {
  id: string;
  name: string;
  mimeType: string;
  size?: string;
  modifiedTime: string;
  webViewLink?: string;
}

export interface GoogleSheet {
  id: string;
  name: string;
  sheets: Array<{
    title: string;
    sheetId: number;
  }>;
}

class GoogleApiService {
  private async getAccessToken(): Promise<string> {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session?.provider_token) {
      throw new Error('No Google access token available. Please sign in with Google.');
    }
    return session.provider_token;
  }

  private async makeRequest(url: string, options: RequestInit = {}) {
    const token = await this.getAccessToken();
    
    const response = await fetch(url, {
      ...options,
      headers: {
        ...options.headers,
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error(`Google API request failed: ${response.statusText}`);
    }

    return response.json();
  }

  async getForms(): Promise<GoogleForm[]> {
    try {
      const data = await this.makeRequest('https://forms.googleapis.com/v1/forms');
      
      return (data.forms || []).map((form: any) => ({
        id: form.formId,
        title: form.info?.title || 'Untitled Form',
        description: form.info?.description || '',
        lastModified: form.info?.lastModified || new Date().toISOString(),
      }));
    } catch (error) {
      console.error('Error fetching Google Forms:', error);
      return [];
    }
  }

  async getFormResponses(formId: string): Promise<any[]> {
    try {
      const data = await this.makeRequest(`https://forms.googleapis.com/v1/forms/${formId}/responses`);
      return data.responses || [];
    } catch (error) {
      console.error('Error fetching form responses:', error);
      return [];
    }
  }

  async getDriveFiles(query: string = ''): Promise<GoogleDriveFile[]> {
    try {
      const searchQuery = query || "mimeType contains 'application/' or mimeType contains 'text/' or mimeType='application/pdf'";
      const encodedQuery = encodeURIComponent(searchQuery);
      
      const data = await this.makeRequest(
        `https://www.googleapis.com/drive/v3/files?q=${encodedQuery}&fields=files(id,name,mimeType,size,modifiedTime,webViewLink)&pageSize=50`
      );
      
      return (data.files || []).map((file: any) => ({
        id: file.id,
        name: file.name,
        mimeType: file.mimeType,
        size: file.size ? this.formatFileSize(parseInt(file.size)) : undefined,
        modifiedTime: file.modifiedTime,
        webViewLink: file.webViewLink,
      }));
    } catch (error) {
      console.error('Error fetching Google Drive files:', error);
      return [];
    }
  }

  async getSheets(): Promise<GoogleSheet[]> {
    try {
      const data = await this.makeRequest(
        'https://www.googleapis.com/drive/v3/files?q=mimeType="application/vnd.google-apps.spreadsheet"&fields=files(id,name)&pageSize=50'
      );
      
      const sheets = await Promise.all(
        (data.files || []).map(async (file: any) => {
          try {
            const sheetData = await this.makeRequest(
              `https://sheets.googleapis.com/v4/spreadsheets/${file.id}?fields=sheets.properties(title,sheetId)`
            );
            
            return {
              id: file.id,
              name: file.name,
              sheets: (sheetData.sheets || []).map((sheet: any) => ({
                title: sheet.properties.title,
                sheetId: sheet.properties.sheetId,
              })),
            };
          } catch (error) {
            console.error(`Error fetching sheet details for ${file.id}:`, error);
            return {
              id: file.id,
              name: file.name,
              sheets: [],
            };
          }
        })
      );
      
      return sheets;
    } catch (error) {
      console.error('Error fetching Google Sheets:', error);
      return [];
    }
  }

  async getSheetData(sheetId: string, range: string = 'A1:Z1000'): Promise<any[][]> {
    try {
      const data = await this.makeRequest(
        `https://sheets.googleapis.com/v4/spreadsheets/${sheetId}/values/${range}`
      );
      
      return data.values || [];
    } catch (error) {
      console.error('Error fetching sheet data:', error);
      return [];
    }
  }

  private formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  }
}

export const googleApi = new GoogleApiService();