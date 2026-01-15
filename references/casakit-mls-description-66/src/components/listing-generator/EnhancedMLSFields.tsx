import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Label } from '@/components/ui/label';
import { 
  
  MapPin, 
  DollarSign, 
  Home, 
  Waves, 
  Sofa, 
  MessageSquare, 
  Users,
  FileText,
  Link
} from 'lucide-react';
import { CopyButton } from '@/components/ui/copy-button';
import { MLS_FIELD_METADATA } from './enhanced-mls-types';
import type { EnhancedMLSFields as EnhancedMLSFieldsType } from './enhanced-mls-types';

interface EnhancedMLSFieldsComponentProps {
  mlsFields: EnhancedMLSFieldsType;
  onFieldChange?: (section: string, field: string, value: any) => void;
  readOnly?: boolean;
}

const fieldSections = [
  { 
    key: 'location', 
    title: 'Location Details', 
    icon: MapPin, 
    essential: true,
    description: 'Address, lot details, and geographic information'
  },
  { 
    key: 'amounts', 
    title: 'Pricing & Dates', 
    icon: DollarSign, 
    essential: true,
    description: 'List price, taxes, and important dates'
  },
  { 
    key: 'exterior', 
    title: 'Exterior Features', 
    icon: Home, 
    essential: true,
    description: 'Property type, style, and exterior characteristics'
  },
  { 
    key: 'interior', 
    title: 'Interior Details', 
    icon: Sofa, 
    essential: true,
    description: 'Rooms, features, and interior specifications'
  },
  { 
    key: 'waterfront', 
    title: 'Waterfront/Rural', 
    icon: Waves, 
    essential: false,
    description: 'Waterfront and rural property features'
  },
  { 
    key: 'comments', 
    title: 'Comments & Remarks', 
    icon: MessageSquare, 
    essential: true,
    description: 'Client remarks, inclusions, and exclusions'
  },
  { 
    key: 'other', 
    title: 'Agent & Distribution', 
    icon: Users, 
    essential: true,
    description: 'Agent information and listing distribution settings'
  }
];

const formatFieldName = (fieldName: string): string => {
  return fieldName
    .replace(/([A-Z])/g, ' $1')
    .replace(/^./, str => str.toUpperCase())
    .replace(/sqft/gi, 'Sq Ft')
    .replace(/Uffi/g, 'UFFI')
    .replace(/Hst/g, 'HST')
    .replace(/Pin/g, 'PIN')
    .replace(/Ddf/g, 'DDF')
    .replace(/Idx/g, 'IDX');
};

const generatePlaceholder = (fieldName: string, sectionKey: string): any => {
  const metadata = getFieldMetadata(sectionKey, fieldName);
  
  if (metadata?.type === 'currency') {
    return '$0';
  }
  
  if (metadata?.type === 'boolean') {
    return null; // Will show as "Select Yes/No"
  }
  
  if (metadata?.copyFormat === 'array') {
    return [];
  }
  
  if (metadata?.type === 'number') {
    if (fieldName.toLowerCase().includes('year')) return 'YYYY';
    if (fieldName.toLowerCase().includes('phone')) return '(555) 123-4567';
    return '0';
  }
  
  if (metadata?.type === 'email') {
    return 'agent@email.com';
  }
  
  if (fieldName.toLowerCase().includes('postal')) {
    return 'A1A 1A1';
  }
  
  if (fieldName.toLowerCase().includes('address') || fieldName.toLowerCase().includes('street')) {
    return '123 Main St';
  }
  
  if (fieldName.toLowerCase().includes('description') || fieldName.toLowerCase().includes('remarks')) {
    return `Enter ${formatFieldName(fieldName).toLowerCase()}`;
  }
  
  return `Enter ${formatFieldName(fieldName).toLowerCase()}`;
};

const generateSectionPlaceholders = (sectionKey: string): any => {
  const sectionMetadata = MLS_FIELD_METADATA[sectionKey];
  if (!sectionMetadata) return {};
  
  const placeholders: any = {};
  Object.keys(sectionMetadata).forEach(fieldName => {
    placeholders[fieldName] = generatePlaceholder(fieldName, sectionKey);
  });
  
  return placeholders;
};

const getFieldMetadata = (sectionKey: string, fieldName: string) => {
  return MLS_FIELD_METADATA[sectionKey]?.[fieldName];
};

const renderFieldValue = (value: any, fieldName: string, sectionKey: string, isPlaceholder: boolean = false): React.ReactNode => {
  // Special handling for auto-synced fields
  const isAutoSynced = fieldName === 'remarksForClients' && sectionKey === 'comments';
  
  if (value === null || value === undefined) {
    const metadata = getFieldMetadata(sectionKey, fieldName);
    if (metadata?.type === 'boolean') {
      return <span className="text-muted-foreground italic text-sm">Select Yes/No</span>;
    }
    return <span className="text-muted-foreground italic text-sm">Not specified</span>;
  }

  const metadata = getFieldMetadata(sectionKey, fieldName);

  // Special styling for auto-synced fields
  if (isAutoSynced && value) {
    return (
      <div className="space-y-2">
        <div className="text-sm text-foreground whitespace-pre-wrap leading-relaxed">
          {value}
        </div>
        <div className="flex items-center gap-1 px-2 py-1 bg-blue-50 dark:bg-blue-950/30 rounded-md w-fit">
          <Link className="h-3 w-3 text-blue-600 dark:text-blue-400" />
          <span className="text-xs text-blue-600 dark:text-blue-400 font-medium">Auto-synced with MLS Description</span>
        </div>
      </div>
    );
  }

  if (typeof value === 'boolean') {
    return (
      <div className="flex items-center gap-2">
        <div className={`w-2 h-2 rounded-full ${value ? 'bg-primary' : 'bg-muted'}`} />
        <span className="text-sm">{value ? 'Yes' : 'No'}</span>
      </div>
    );
  }

  if (Array.isArray(value)) {
    if (value.length === 0) {
      return <span className="text-muted-foreground italic text-sm">None</span>;
    }
    return (
      <div className="flex flex-wrap gap-1">
        {value.map((item, index) => (
          <Badge key={index} variant="outline" className="text-xs">
            {item}
          </Badge>
        ))}
      </div>
    );
  }

  if (typeof value === 'number') {
    if (metadata?.type === 'currency' || fieldName.toLowerCase().includes('price') || fieldName.toLowerCase().includes('tax')) {
      return <span className="text-sm font-medium">${value.toLocaleString()}</span>;
    }
    if (fieldName.toLowerCase().includes('sqft') || fieldName.toLowerCase().includes('footage')) {
      return <span className="text-sm">{value.toLocaleString()} sq ft</span>;
    }
    if (fieldName.toLowerCase().includes('depth') || fieldName.toLowerCase().includes('front')) {
      return <span className="text-sm">{value} ft</span>;
    }
    return <span className="text-sm">{value.toLocaleString()}</span>;
  }

  return <span className={`text-sm ${isPlaceholder ? 'text-muted-foreground italic' : ''}`}>{value}</span>;
};

const SectionCard = ({ 
  section, 
  data, 
  readOnly
}: { 
  section: typeof fieldSections[0]; 
  data: any; 
  readOnly?: boolean;
}) => {
  // Show all fields defined in metadata; use actual values or empty when missing
  const sectionMetadata = MLS_FIELD_METADATA[section.key] || {};
  const allFieldNames = Object.keys(sectionMetadata);
  const isPlaceholder = !data;
  
  const hasRealData = data && Object.values(data).some(value => 
    value !== null && value !== undefined && 
    (!Array.isArray(value) || value.length > 0)
  );

  const fieldCount = allFieldNames.length;
  const filledCount = data ? Object.values(data).filter(value => 
    value !== null && value !== undefined && 
    (!Array.isArray(value) || value.length > 0)
  ).length : 0;

  const getCopyFormat = (fieldName: string, sectionKey: string) => {
    const metadata = getFieldMetadata(sectionKey, fieldName);
    return metadata?.copyFormat || 'raw';
  };

  return (
    <Card className={`transition-all duration-200 ${hasRealData ? 'border-primary/20 bg-primary/5' : 'border-border/40'} ${isPlaceholder ? 'border-dashed' : ''}`}>
      <CardHeader className="pb-4">
        <div className="flex items-center justify-between w-full">
          <div className="flex items-center gap-3">
            <section.icon className="h-5 w-5 text-primary" />
            <div className="text-left">
              <CardTitle className="text-lg font-medium">{section.title}</CardTitle>
              <p className="text-xs text-muted-foreground mt-0.5">{section.description}</p>
            </div>
            {isPlaceholder && (
              <Badge variant="outline" className="text-xs text-muted-foreground">Template</Badge>
            )}
          </div>
          <div className="flex items-center gap-3">
            <div className="text-sm text-muted-foreground">
              {filledCount}/{fieldCount} fields
            </div>
          </div>
        </div>
      </CardHeader>
      
      <CardContent className="pt-0">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {allFieldNames.map((fieldName) => {
            const metadata = getFieldMetadata(section.key, fieldName);
            const copyFormat = getCopyFormat(fieldName, section.key);
            const actualValue = data?.[fieldName];
            const hasRealValue = data && data[fieldName] !== null && data[fieldName] !== undefined && (!Array.isArray(data[fieldName]) || data[fieldName].length > 0);
            
            return (
              <div key={fieldName} className={`space-y-2 ${!hasRealValue && isPlaceholder ? 'opacity-60' : ''}`}>
                <div className="flex items-center justify-between">
                  <Label className="text-sm font-medium text-muted-foreground flex items-center gap-2">
                    {metadata?.label || formatFieldName(fieldName)}
                    {metadata?.required && (
                      <span className="text-destructive text-xs">*</span>
                    )}
                  </Label>
                  <CopyButton
                    value={actualValue}
                    fieldName={metadata?.label || formatFieldName(fieldName)}
                    format={copyFormat}
                    size="micro"
                    variant="ghost"
                  />
                </div>
                <div className="min-h-[24px] flex items-center">
                  {renderFieldValue(actualValue, fieldName, section.key, false)}
                </div>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
};

export const EnhancedMLSFields: React.FC<EnhancedMLSFieldsComponentProps> = ({ 
  mlsFields, 
  onFieldChange, 
  readOnly = true 
}) => {
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="space-y-1">
          <h3 className="text-2xl font-light tracking-tight text-foreground flex items-center gap-2">
            <FileText className="h-6 w-6 text-primary" />
            Enhanced MLS Fields
          </h3>
          <p className="text-sm text-muted-foreground font-light">
            Professional MLS data ready for one-click copying
          </p>
        </div>
      </div>

      {/* Field Sections */}
      <div className="space-y-4">
        {fieldSections.map((section) => {
          const sectionData = mlsFields[section.key as keyof EnhancedMLSFieldsType];
          return (
            <SectionCard
              key={section.key}
              section={section}
              data={sectionData}
              readOnly={readOnly}
            />
          );
        })}
      </div>
    </div>
  );
};