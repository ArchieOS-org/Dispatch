import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { ChevronDown, ChevronRight, Copy, Download, Database } from "lucide-react";
import type { MLSFields } from "./mls-types";

interface MinimalMLSFieldsProps {
  mlsFields: MLSFields;
  onFieldChange?: (section: string, field: string, value: any) => void;
  readOnly?: boolean;
}

const fieldSections = [
  { key: 'basic', title: 'Property Basics', icon: Database, essential: true },
  { key: 'location', title: 'Location Details', icon: Database, essential: true },
  { key: 'exterior', title: 'Exterior Features', icon: Database, essential: false },
  { key: 'interior', title: 'Interior Details', icon: Database, essential: false },
  { key: 'amounts', title: 'Pricing & Dates', icon: Database, essential: true },
  { key: 'utilities', title: 'Utilities & Services', icon: Database, essential: false },
  { key: 'rooms', title: 'Room Dimensions', icon: Database, essential: false },
  { key: 'waterfront', title: 'Waterfront/Rural', icon: Database, essential: false }
];

const formatFieldName = (fieldName: string): string => {
  return fieldName
    .replace(/([A-Z])/g, ' $1')
    .replace(/^./, str => str.toUpperCase())
    .replace(/sqft/gi, 'Sq Ft')
    .replace(/Uffi/g, 'UFFI')
    .replace(/Hst/g, 'HST')
    .replace(/Pin/g, 'PIN');
};

const renderFieldValue = (value: any, fieldName: string): React.ReactNode => {
  if (value === null || value === undefined) {
    return <span className="text-muted-foreground italic text-sm">Not specified</span>;
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
    // Format numbers based on field type
    if (fieldName.toLowerCase().includes('price') || fieldName.toLowerCase().includes('tax')) {
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

  return <span className="text-sm">{value}</span>;
};

const SectionCard = ({ 
  section, 
  data, 
  isOpen, 
  onToggle, 
  readOnly 
}: { 
  section: typeof fieldSections[0]; 
  data: any; 
  isOpen: boolean; 
  onToggle: () => void;
  readOnly?: boolean;
}) => {
  const hasData = data && Object.values(data).some(value => 
    value !== null && value !== undefined && 
    (!Array.isArray(value) || value.length > 0)
  );

  const fieldCount = data ? Object.keys(data).length : 0;
  const filledCount = data ? Object.values(data).filter(value => 
    value !== null && value !== undefined && 
    (!Array.isArray(value) || value.length > 0)
  ).length : 0;

  return (
    <Card className={`transition-all duration-200 ${hasData ? 'border-primary/20 bg-primary/5' : 'border-border/40'}`}>
      <Collapsible open={isOpen} onOpenChange={onToggle}>
        <CollapsibleTrigger asChild>
          <CardHeader className="pb-4 cursor-pointer hover:bg-muted/30 transition-colors">
            <div className="flex items-center justify-between w-full">
              <div className="flex items-center gap-3">
                <section.icon className="h-5 w-5 text-primary" />
                <CardTitle className="text-lg font-medium">{section.title}</CardTitle>
                {section.essential && (
                  <Badge variant="secondary" className="text-xs">Essential</Badge>
                )}
              </div>
              <div className="flex items-center gap-3">
                <div className="text-sm text-muted-foreground">
                  {filledCount}/{fieldCount} fields
                </div>
                {isOpen ? (
                  <ChevronDown className="h-4 w-4 text-muted-foreground" />
                ) : (
                  <ChevronRight className="h-4 w-4 text-muted-foreground" />
                )}
              </div>
            </div>
          </CardHeader>
        </CollapsibleTrigger>
        
        <CollapsibleContent>
          <CardContent className="pt-0">
            {data ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {Object.entries(data).map(([fieldName, value]) => (
                  <div key={fieldName} className="space-y-2">
                    <Label className="text-sm font-medium text-muted-foreground">
                      {formatFieldName(fieldName)}
                    </Label>
                    <div className="min-h-[24px] flex items-center">
                      {renderFieldValue(value, fieldName)}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-muted-foreground">
                <span className="text-sm italic">No data available for this section</span>
              </div>
            )}
          </CardContent>
        </CollapsibleContent>
      </Collapsible>
    </Card>
  );
};

export const MinimalMLSFields = ({ 
  mlsFields, 
  onFieldChange, 
  readOnly = true 
}: MinimalMLSFieldsProps) => {
  const [openSections, setOpenSections] = useState<Set<string>>(
    new Set(['basic', 'location', 'amounts']) // Essential sections open by default
  );

  const toggleSection = (sectionKey: string) => {
    const newOpenSections = new Set(openSections);
    if (newOpenSections.has(sectionKey)) {
      newOpenSections.delete(sectionKey);
    } else {
      newOpenSections.add(sectionKey);
    }
    setOpenSections(newOpenSections);
  };

  const expandAll = () => {
    setOpenSections(new Set(fieldSections.map(s => s.key)));
  };

  const collapseAll = () => {
    setOpenSections(new Set(['basic'])); // Keep at least basic open
  };

  const exportData = () => {
    const dataStr = JSON.stringify(mlsFields, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'mls-fields.json';
    link.click();
    URL.revokeObjectURL(url);
  };

  const copyJSON = async () => {
    try {
      await navigator.clipboard.writeText(JSON.stringify(mlsFields, null, 2));
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="space-y-1">
          <h3 className="text-2xl font-light tracking-tight text-foreground">
            MLS Fields
          </h3>
          <p className="text-sm text-muted-foreground font-light">
            Comprehensive property data for MLS submission
          </p>
        </div>
        
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={collapseAll}
            className="text-xs"
          >
            Collapse All
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={expandAll}
            className="text-xs"
          >
            Expand All
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={copyJSON}
            className="text-xs gap-2"
          >
            <Copy className="h-3 w-3" />
            Copy JSON
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={exportData}
            className="text-xs gap-2"
          >
            <Download className="h-3 w-3" />
            Export
          </Button>
        </div>
      </div>

      {/* Field Sections */}
      <div className="space-y-4">
        {fieldSections.map((section) => {
          const sectionData = mlsFields[section.key as keyof MLSFields];
          return (
            <SectionCard
              key={section.key}
              section={section}
              data={sectionData}
              isOpen={openSections.has(section.key)}
              onToggle={() => toggleSection(section.key)}
              readOnly={readOnly}
            />
          );
        })}
      </div>
    </div>
  );
};