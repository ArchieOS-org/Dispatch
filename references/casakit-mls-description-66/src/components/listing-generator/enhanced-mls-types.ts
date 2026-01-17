/**
 * Enhanced MLS Types & Interfaces
 * 
 * Comprehensive structure matching real MLS requirements
 * with copy functionality and field metadata
 */

export interface MLSFieldMetadata {
  label: string;
  type: 'text' | 'number' | 'select' | 'boolean' | 'currency' | 'date' | 'postal' | 'phone' | 'email';
  required?: boolean;
  copyFormat?: 'raw' | 'formatted' | 'currency' | 'boolean' | 'array';
  unit?: string;
  pattern?: string;
}

// Location Fields
export interface LocationFields {
  assessmentRollNumber?: string;
  pin?: string;
  additionalPin?: string;
  area?: string;
  municipality?: string;
  community?: string;
  streetDirectionPrefix?: string;
  streetNumber?: number;
  streetName?: string;
  abbreviation?: string;
  streetDirection?: string;
  apartmentUnit?: string;
  postalCode?: string;
  frontingOn?: string;
  legalDescription?: string;
  lotFront?: number;
  lotDepth?: number;
  lotSizeCode?: string;
  lotIrregularities?: string;
  lotShape?: string;
  lotSizeSource?: string;
  lotSizeArea?: number;
  lotSizeAreaCode?: string;
  winterized?: string;
  acreage?: string;
  waterfront?: boolean;
  zoning?: string;
  directions?: string;
  mainCrossStreets?: string;
  latitude?: number;
  longitude?: number;
}

// Amounts/Dates Fields
export interface AmountsFields {
  listPrice?: number;
  hstApplicable?: string;
  developmentChargesPaid?: string;
  taxes?: number;
  taxYear?: number;
  assessment?: number;
  assessmentYear?: number;
  contractCommencement?: string;
  expiryDate?: string;
  possessionDate?: string;
  possessionRemarks?: string;
  possessionType?: string;
  holdoverDays?: number;
  sellerName?: string;
  mortgageComments?: string;
  phasedTaxAssessedValue?: number;
  roadAccessFee?: number;
  leasedLandFee?: number;
  localImprovements?: boolean;
  localImprovementsComments?: string;
}

// Exterior Fields
export interface ExteriorFields {
  propertyType?: string;
  parcelOfTiedLand?: boolean;
  assignment?: boolean;
  fractionalOwnership?: boolean;
  style?: string;
  view?: string[];
  exterior?: string[];
  exteriorFeatures?: string[];
  foundationDetail?: string[];
  roof?: string[];
  topography?: string[];
  garage?: boolean;
  garageType?: string;
  garageParkingSpaces?: number;
  parkingDrive?: string[];
  driveParkingSpaces?: number;
  totalParkingSpaces?: number;
  water?: string;
  pool?: string;
  sewers?: string;
  retirementCommunity?: boolean;
  physicallyHandicappedEquipped?: boolean;
  specialDesignation?: string[];
  approximateAge?: string;
  yearBuilt?: number;
  yearBuiltSource?: string;
  approximateSquareFootage?: string;
  aboveGradeFinishedSQFT?: number;
  aboveGradeFinishedSQFTSource?: string;
  belowGradeFinishedSQFT?: number;
  belowGradeFinishedSQFTSource?: string;
  otherSQFT?: number;
  totalUnfinishedSQFT?: number;
  propertyFeatures?: string[];
  otherStructures?: string[];
  securityFeatures?: string[];
  waterSupplyType?: string[];
  farmAgriculture?: string[];
  farmFeatures?: string[];
  soilType?: string;
  waterMeter?: boolean;
  surveyType?: string;
  surveyYear?: number;
  wellCapacity?: number;
  wellDepth?: number;
  cable?: boolean;
  hydro?: boolean;
  gasNatural?: boolean;
  municipalWater?: boolean;
  telephone?: boolean;
}

// Waterfront/Rural Fields
export interface WaterfrontFields {
  waterfrontType?: string[];
  bodyOfWaterName?: string;
  waterBodyType?: string;
  island?: boolean;
  waterView?: string[];
  channelName?: string;
  waterFrontage?: number;
  seasonalDwelling?: boolean;
  accessToProperty?: string[];
  shoreline?: string;
  waterfrontFeatures?: string[];
  shorelineExposure?: string;
  shorelineAllowance?: string;
  alternativePower?: string[];
  sewage?: string[];
  waterDeliveryFeatures?: string[];
  easementsRestrictions?: string[];
  ruralServices?: string[];
  waterfrontAccessoryBuildings?: string[];
  dockingType?: string[];
}

// Interior Fields
export interface InteriorFields {
  numberOfRooms?: number;
  roomsPlus?: string[];
  numberOfBedrooms?: number;
  bedroomsPlus?: string[];
  numberOfKitchens?: number;
  kitchensPlus?: string[];
  numberOfWashrooms?: number;
  washroomPieces?: number;
  washroomLevel?: string;
  interiorFeatures?: string[];
  familyRoomBonusRoom?: boolean;
  basement?: string[];
  fireplaceStove?: boolean;
  fireplaceFeatures?: string[];
  numberOfFireplaces?: number;
  heatSource?: string;
  heatType?: string;
  airConditioning?: string;
  uffi?: string;
  laundryLevel?: string;
  accessibilityFeatures?: string[];
  elevatorLift?: boolean;
  leaseToOwnItems?: string[];
  underContract?: string[];
}

// Room Detail Fields
export interface RoomDetailFields {
  roomLevel?: string;
  roomType?: string;
  length?: number;
  width?: number;
  height?: number;
  description1?: string;
  description2?: string;
  description3?: string;
}

// Comments Fields
export interface CommentsFields {
  remarksForClients?: string;
  offerRemarks?: string;
  inclusions?: string;
  exclusions?: string;
  rentalItems?: string;
  underContractMonthlyCosts?: string;
  realtorOnlyRemarks?: string;
}

// Other/Agent Fields
export interface OtherFields {
  listingBrokerage?: string;
  listingBrokeragePhone?: string;
  listingBrokerageFax?: string;
  salesperson1?: string;
  salesperson1Phone?: string;
  salesperson1Email?: string;
  salesperson2Brokerage?: string;
  salesperson2?: string;
  salesperson2Phone?: string;
  salesperson2Email?: string;
  commissionToCooperatingBrokerage?: string;
  sellerPropertyInfoStatement?: boolean;
  energyCertificate?: boolean;
  certificationLevel?: string;
  greenPropertyInfoStatement?: boolean;
  distributeToInternet?: boolean;
  displayAddressOnInternet?: boolean;
  distributeToDDF?: boolean;
  permissionToContactBroker?: boolean;
  realtorSignOnProperty?: boolean;
  brokerOpenHouseDate?: string;
  brokerOpenHouseTime?: string;
  brokerOpenHouseNotes?: string;
  appointmentsShowingRemarks?: string;
  showingRequirements?: string[];
  occupancy?: string;
  contactAfterExpired?: boolean;
}

// Enhanced MLS Fields Structure
export interface EnhancedMLSFields {
  location?: LocationFields;
  amounts?: AmountsFields;
  exterior?: ExteriorFields;
  waterfront?: WaterfrontFields;
  interior?: InteriorFields;
  roomDetails?: RoomDetailFields[];
  comments?: CommentsFields;
  other?: OtherFields;
}

// Field Metadata Definitions
export const MLS_FIELD_METADATA: Record<string, Record<string, MLSFieldMetadata>> = {
  location: {
    assessmentRollNumber: { label: 'Assessment Roll Number (ARN)', type: 'text', required: true },
    pin: { label: 'PIN#', type: 'text', required: true },
    additionalPin: { label: 'Additional PIN#', type: 'text' },
    area: { label: 'Area', type: 'select', required: true },
    municipality: { label: 'Municipality', type: 'select', required: true },
    community: { label: 'Community', type: 'select' },
    streetNumber: { label: 'Street Number', type: 'number', required: true },
    streetName: { label: 'Street Name', type: 'text', required: true },
    abbreviation: { label: 'Abbreviation', type: 'select', required: true },
    apartmentUnit: { label: 'Apartment/Unit #', type: 'text' },
    postalCode: { label: 'Postal Code', type: 'postal', required: true, pattern: 'A1A 1A1' },
    lotFront: { label: 'Lot Front', type: 'number', required: true, unit: 'ft' },
    lotDepth: { label: 'Lot Depth', type: 'number', required: true, unit: 'ft' },
    waterfront: { label: 'Waterfront', type: 'boolean', required: true, copyFormat: 'boolean' },
    directions: { label: 'Directions', type: 'text', required: true },
  },
  amounts: {
    listPrice: { label: 'List Price', type: 'currency', required: true, copyFormat: 'currency' },
    hstApplicable: { label: 'HST Applicable', type: 'select', required: true },
    taxes: { label: 'Taxes', type: 'currency', required: true, copyFormat: 'currency' },
    taxYear: { label: 'Tax Year', type: 'number', required: true },
    contractCommencement: { label: 'Contract Commencement', type: 'date', required: true },
    expiryDate: { label: 'Expiry Date', type: 'date', required: true },
    possessionRemarks: { label: 'Possession Remarks', type: 'text', required: true },
    possessionType: { label: 'Possession Type', type: 'select', required: true },
    holdoverDays: { label: 'Holdover Days', type: 'number', required: true },
    sellerName: { label: 'Seller Name', type: 'text', required: true },
  },
  exterior: {
    propertyType: { label: 'Property Type', type: 'select', required: true },
    style: { label: 'Style', type: 'select', required: true },
    exterior: { label: 'Exterior', type: 'select', required: true, copyFormat: 'array' },
    garage: { label: 'Garage', type: 'boolean', required: true, copyFormat: 'boolean' },
    garageType: { label: 'Garage Type', type: 'select', required: true },
    garageParkingSpaces: { label: 'Garage Parking Spaces', type: 'number', required: true },
    totalParkingSpaces: { label: 'Total Parking Spaces', type: 'number', required: true },
    pool: { label: 'Pool', type: 'select', required: true },
    sewers: { label: 'Sewers', type: 'select', required: true },
    specialDesignation: { label: 'Special Designation', type: 'select', required: true, copyFormat: 'array' },
    aboveGradeFinishedSQFT: { label: 'Above Grade Finished SQFT', type: 'number', required: true, unit: 'sq ft' },
    surveyType: { label: 'Survey Type', type: 'select', required: true },
  },
  interior: {
    numberOfRooms: { label: '# of Rooms', type: 'number', required: true },
    numberOfBedrooms: { label: '# of Bedrooms', type: 'number', required: true },
    numberOfKitchens: { label: '# of Kitchens', type: 'number', required: true },
    interiorFeatures: { label: 'Interior Features', type: 'select', required: true, copyFormat: 'array' },
    familyRoomBonusRoom: { label: 'Family Room/Bonus Room', type: 'boolean', required: true, copyFormat: 'boolean' },
    basement: { label: 'Basement', type: 'select', required: true, copyFormat: 'array' },
    heatSource: { label: 'Heat Source', type: 'select', required: true },
    heatType: { label: 'Heat Type', type: 'select', required: true },
    airConditioning: { label: 'Air Conditioning', type: 'select', required: true },
  },
  comments: {
    remarksForClients: { label: 'Remarks for Clients', type: 'text', required: true },
  },
  other: {
    salesperson1: { label: 'Salesperson 1', type: 'select', required: true },
    salesperson1Phone: { label: 'Salesperson 1 Phone #', type: 'phone', required: true },
    salesperson1Email: { label: 'Salesperson 1 Email', type: 'email', required: true },
    distributeToInternet: { label: 'Distribute to Internet', type: 'boolean', required: true, copyFormat: 'boolean' },
    displayAddressOnInternet: { label: 'Display Address on Internet', type: 'boolean', required: true, copyFormat: 'boolean' },
    distributeToDDF: { label: 'Distribute to DDF/IDX', type: 'boolean', required: true, copyFormat: 'boolean' },
    permissionToContactBroker: { label: 'Permission To Contact Listing Broker', type: 'boolean', required: true, copyFormat: 'boolean' },
    showingRequirements: { label: 'Showing Requirements', type: 'select', required: true, copyFormat: 'array' },
    occupancy: { label: 'Occupancy', type: 'select', required: true },
    contactAfterExpired: { label: 'Contact After Expired', type: 'boolean', required: true, copyFormat: 'boolean' },
  }
};

export interface PropertyStoryWithEnhancedMLS {
  mlsDescription: string;
  storyText: string;
  mlsFields?: EnhancedMLSFields;
  propertyHighlights?: string[];
  marketingTags?: string[];
}
