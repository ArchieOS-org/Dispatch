export interface AddressFields {
  apartmentUnit?: string;
  streetDirection?: string;
}

export interface BasicFields {
  brokerage?: string;
  member?: string;
  propertyClass?: string;
  propertyType?: string;
  searchBy?: string;
  searchByAddress?: string;
  transactionType?: string;
}

export interface ExteriorFields {
  parkingSpacesDrive?: number;
  parkingSpacesTotal?: number;
  approximateAge?: number;
  approximateSquareFootage?: number;
  belowGradeFinishedSQFT?: number;
  belowGradeFinishedSQFTSource?: string;
  cable?: boolean;
  driveParkingSpaces?: number;
  exterior?: string;
  foundationDetail?: string;
  garage?: boolean;
  garageParkingSpaces?: number;
  garageType?: string;
  gasNatural?: boolean;
  heatSource?: string;
  heatType?: string;
  hydro?: boolean;
  interiorFeatures?: string[];
  otherSQFT?: number;
  otherStructures?: string[];
  parcelOfTiedLand?: string;
  parkingDrive?: string;
  pool?: boolean;
  propertyFeatures?: string[];
  roof?: string;
  securityFeatures?: string[];
  sewer?: string;
  specialDesignation?: string;
  style?: string;
  surveyType?: string;
  surveyYear?: number;
  telephone?: boolean;
  topography?: string;
  totalUnfinishedSQFT?: number;
  water?: string;
  waterMeter?: boolean;
  waterSupplyType?: string;
  wellCapacity?: number;
  wellDepth?: number;
  yearBuilt?: number;
  yearBuiltSource?: string;
}

export interface InteriorFields {
  bedrooms?: number;
  bedroomsPlus?: number;
  kitchens?: number;
  rooms?: number;
  roomsPlus?: number;
  airConditioning?: boolean;
  basement?: string;
  familyRoomBonusRoom?: boolean;
  fireplaceStove?: boolean;
  heatSource?: string;
  heatType?: string;
  interiorFeatures?: string[];
  laundryLevel?: string;
  numberOfFireplaces?: number;
  uffi?: boolean;
  underContract?: boolean;
  washroom1?: string;
  washroom2?: string;
}

export interface LocationFields {
  abbreviation?: string;
  area?: string;
  community?: string;
  directions?: string;
  frontingOn?: string;
  legalDescription?: string;
  lotDepth?: number;
  lotFront?: number;
  lotSizeCode?: string;
  mainCrossStreets?: string;
  municipality?: string;
  pin?: string;
  postalCode?: string;
  streetName?: string;
  streetNumber?: string;
  waterfront?: boolean;
  zoning?: string;
}

export interface AmountsFields {
  assessmentYear?: number;
  contractCommencement?: string;
  expiryDate?: string;
  hstApplicable?: boolean;
  holdoverDays?: number;
  listPrice?: number;
  localImprovements?: number;
  possessionRemarks?: string;
  possessionType?: string;
  sellerName?: string;
  taxYear?: number;
  taxes?: number;
}

export interface RoomsFields {
  mainLivingRoom?: string;
  mainKitchen?: string;
  mainPrimaryBedroom?: string;
  mainBedroom?: string;
  basementRecreation?: string;
  basementBedroom?: string;
  basementLaundry?: string;
}

export interface UtilitiesFields {
  cable?: boolean;
  gasNatural?: boolean;
  hydro?: boolean;
  municipalWater?: boolean;
  telephone?: boolean;
}

export interface WaterfrontFields {
  accessToProperty?: string;
  alternativePower?: string;
  bodyOfWaterName?: string;
  channelName?: string;
  dockingType?: string;
  easementsRestrictions?: string;
  island?: boolean;
  ruralServices?: string[];
  seasonalDwelling?: boolean;
  sewage?: string;
  shoreline?: string;
  shorelineAllowance?: string;
  shorelineExposure?: string;
  waterBodyType?: string;
  waterDeliveryFeatures?: string[];
  waterFrontage?: number;
  waterView?: string;
  waterfrontAccessoryBuildings?: string[];
  waterfrontFeatures?: string[];
  waterfrontType?: string;
}

export interface MLSFields {
  address: AddressFields;
  basic: BasicFields;
  exterior: ExteriorFields;
  interior: InteriorFields;
  location: LocationFields;
  amounts: AmountsFields;
  rooms: RoomsFields;
  utilities: UtilitiesFields;
  waterfront?: WaterfrontFields;
}

export interface PropertyStoryWithMLS {
  walkthrough: string;
  mlsDescription: string;
  photos: Array<{
    id: string;
    url: string;
    description: string;
    category: string;
    features: string[];
    storyText?: string;
  }>;
  mlsFields: MLSFields;
}