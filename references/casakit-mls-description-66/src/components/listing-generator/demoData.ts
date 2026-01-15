import { Session, SessionData } from '@/services/backend/interfaces';

// Demo sessions for UI testing
export const demoSessions: Session[] = [
  {
    id: 'demo-1',
    name: '123 Ocean View Drive',
    created_at: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(), // 2 hours ago
    updated_at: new Date(Date.now() - 1 * 60 * 60 * 1000).toISOString(), // 1 hour ago
    last_accessed_at: new Date(Date.now() - 30 * 60 * 1000).toISOString(), // 30 minutes ago
  },
  {
    id: 'demo-2',
    name: '456 Downtown Avenue',
    created_at: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(), // Yesterday
    updated_at: new Date(Date.now() - 23 * 60 * 60 * 1000).toISOString(),
    last_accessed_at: new Date(Date.now() - 22 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'demo-3',
    name: '789 Maple Street',
    created_at: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(), // 3 days ago
    updated_at: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(),
    last_accessed_at: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'demo-4',
    name: '321 Victorian Lane',
    created_at: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(), // 1 week ago
    updated_at: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
    last_accessed_at: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'demo-5',
    name: '654 Modern Way',
    created_at: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString(), // 2 weeks ago
    updated_at: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString(),
    last_accessed_at: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString(),
  },
];

export const demoSessionData: Record<string, SessionData> = {
  'demo-1': {
    userInput: 'Stunning waterfront property with panoramic ocean views, private beach access, and luxury finishes throughout. Features include gourmet kitchen, master suite with spa-like bathroom, wine cellar, and infinity pool.',
    propertyType: 'house',
    photos: [],
    media: [],
    generatedDescription: 'WATERFRONT LUXURY ESTATE - Discover unparalleled elegance in this breathtaking oceanfront sanctuary. This architectural masterpiece seamlessly blends contemporary design with coastal sophistication, offering 4,200 sq ft of meticulously crafted living space. The heart of the home showcases a gourmet kitchen with premium European appliances, quartz waterfall island, and custom cabinetry. Floor-to-ceiling windows frame spectacular ocean vistas from every room. The master suite serves as a private retreat with panoramic water views, spa-inspired ensuite, and private balcony. Additional highlights include a temperature-controlled wine cellar, infinity pool that appears to merge with the horizon, and direct beach access. This is coastal living redefined.',
    chatMessages: [],
    photoAnalyses: [
      {
        roomType: 'Living Room',
        description: 'Spacious living area with floor-to-ceiling windows overlooking the ocean',
        keyFeatures: ['Ocean views', 'Modern furniture', 'High ceilings', 'Natural light']
      },
      {
        roomType: 'Kitchen',
        description: 'Gourmet kitchen with quartz countertops and premium appliances',
        keyFeatures: ['Waterfall island', 'European appliances', 'Custom cabinetry', 'Wine storage']
      }
    ],
    propertyStory: 'Wake up to endless ocean horizons in this architectural marvel where luxury meets tranquility. Every detail has been thoughtfully curated to create an atmosphere of sophisticated coastal living that feels both grand and intimately welcoming.',
  },
  'demo-2': {
    userInput: 'Modern downtown condo with city views, updated kitchen, hardwood floors, in-unit laundry, and building amenities including gym and rooftop deck.',
    propertyType: 'condo',
    photos: [],
    media: [],
    generatedDescription: 'URBAN SOPHISTICATION AWAITS - Step into this beautifully appointed 2-bedroom, 2-bathroom condo in the heart of downtown. This modern residence features gleaming hardwood floors throughout, an updated kitchen with stainless steel appliances and granite counters, and large windows that showcase stunning city skyline views. The open-concept living space flows seamlessly from kitchen to living room, perfect for both relaxation and entertaining. The master bedroom offers a peaceful retreat with an ensuite bathroom and walk-in closet. Building amenities include a state-of-the-art fitness center, rooftop deck with 360-degree city views, and 24-hour concierge service. Located steps from premier shopping, dining, and public transportation.',
    chatMessages: [],
    photoAnalyses: [
      {
        roomType: 'Living Room',
        description: 'Open-concept living space with city views and modern finishes',
        keyFeatures: ['City views', 'Hardwood floors', 'Open concept', 'Large windows']
      }
    ],
    propertyStory: 'Experience the pulse of the city from your private urban retreat. This sophisticated condo offers the perfect balance of modern comfort and metropolitan convenience.',
  },
  'demo-3': {
    userInput: 'Charming 4-bedroom family home in quiet neighborhood with large backyard, updated bathrooms, eat-in kitchen, and attached 2-car garage.',
    propertyType: 'house',
    photos: [],
    media: [],
    generatedDescription: 'PERFECT FAMILY HOME - Discover comfort and convenience in this delightful 4-bedroom, 3-bathroom home nestled in a peaceful residential neighborhood. This well-maintained property offers 2,100 sq ft of thoughtfully designed living space. The heart of the home features an inviting eat-in kitchen with updated appliances and ample cabinet storage. The spacious living room provides the perfect gathering space for family movie nights. All four bedrooms are generously sized, with the master suite featuring an updated ensuite bathroom. The large, fully fenced backyard offers endless possibilities for outdoor entertainment and play. Additional features include recently updated bathrooms, hardwood floors, and an attached 2-car garage with storage space.',
    chatMessages: [],
    photoAnalyses: [
      {
        roomType: 'Kitchen',
        description: 'Warm and inviting eat-in kitchen with updated appliances',
        keyFeatures: ['Eat-in area', 'Updated appliances', 'Ample storage', 'Family-friendly layout']
      }
    ],
    propertyStory: 'Create lasting memories in this warm and welcoming family home where every corner has been designed with comfort and convenience in mind.',
  },
  'demo-4': {
    userInput: 'Magnificent Victorian mansion with original details, grand staircase, period fixtures, multiple fireplaces, library, and carriage house.',
    propertyType: 'house',
    photos: [],
    media: [],
    generatedDescription: 'HISTORIC VICTORIAN GRANDEUR - Step back in time while enjoying modern comfort in this meticulously preserved 1890s Victorian mansion. This architectural treasure spans 5,400 sq ft across three floors, featuring 6 bedrooms and 4.5 bathrooms. Original details shine throughout, including ornate crown molding, period light fixtures, and stunning hardwood floors. The dramatic entrance showcases a grand curved staircase with hand-carved banister. Multiple fireplaces with original mantels warm the formal living and dining rooms. The library features floor-to-ceiling built-in bookcases and period millwork. Modern updates have been seamlessly integrated while preserving the home\'s historic character. The property includes a restored carriage house perfect for guests or studio space.',
    chatMessages: [],
    photoAnalyses: [
      {
        roomType: 'Foyer',
        description: 'Grand entrance with curved staircase and period details',
        keyFeatures: ['Curved staircase', 'Original millwork', 'High ceilings', 'Period fixtures']
      }
    ],
    propertyStory: 'Own a piece of history in this lovingly preserved Victorian masterpiece where every room tells a story of timeless elegance and architectural artistry.',
  },
  'demo-5': {
    userInput: 'Brand new townhouse in modern complex with open floor plan, quartz counters, stainless appliances, rooftop terrace, and community amenities.',
    propertyType: 'townhouse',
    photos: [],
    media: [],
    generatedDescription: 'CONTEMPORARY TOWNHOUSE LIVING - Experience the best of modern design in this brand-new 3-bedroom, 2.5-bathroom townhouse. This stunning residence features an open-concept main floor with 9-foot ceilings and premium finishes throughout. The gourmet kitchen boasts quartz countertops, stainless steel appliances, and a large island perfect for casual dining. The spacious living area flows seamlessly to a private patio. Upstairs, the master suite features a walk-in closet and luxurious ensuite with dual vanities. The crown jewel is the private rooftop terrace with panoramic views. Community amenities include a fitness center, playground, and walking trails. Prime location with easy access to shopping and dining.',
    chatMessages: [],
    photoAnalyses: [
      {
        roomType: 'Kitchen',
        description: 'Modern kitchen with quartz counters and premium appliances',
        keyFeatures: ['Quartz countertops', 'Stainless appliances', 'Large island', 'Open concept']
      }
    ],
    propertyStory: 'Embrace contemporary living in this thoughtfully designed townhouse where modern amenities meet community convenience in perfect harmony.',
  },
};