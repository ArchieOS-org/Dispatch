# AI-Powered Property Listing Generator

A sophisticated real estate application that leverages AI to create professional MLS listings, property descriptions, and marketing copy from property details and photos.

## ✨ Features

- **AI Photo Analysis**: Automatically analyzes property photos to identify room types, features, and quality scores
- **Smart Photo Sorting**: AI-powered photo sequencing for optimal property presentation
- **MLS Description Generation**: Creates professional, TREB-compliant MLS descriptions
- **Property Story Creation**: Generates compelling walkthrough narratives
- **Multiple Property Types**: Supports luxury, family, investment, condo, first-time buyer, and executive properties
- **Content Modification**: Adjust descriptions for different audiences (luxury, family, investment, emotional appeal)
- **Google Integration**: Import property data from Google Forms and Drive
- **Session Management**: Save and manage multiple property listings
- **User Authentication**: Secure sign-in with Google OAuth

## 🛠️ Technology Stack

- **Frontend**: React 18 + TypeScript + Vite
- **UI Components**: shadcn/ui with Tailwind CSS
- **AI Integration**: Google Gemini 2.5 Pro for content generation
- **Backend**: Supabase (authentication, database, storage)
- **Forms**: React Hook Form with Zod validation
- **File Handling**: Drag-and-drop uploads with image processing
- **State Management**: React hooks with context providers

## 🚀 Getting Started

### Prerequisites

- Node.js 18+ and npm
- Google Gemini API key
- Supabase project (automatically configured)

### Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd property-listing-generator
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   - Create API keys through the application's secret management system
   - Required: `GOOGLE_GEMINI_API_KEY`

4. **Start development server**
   ```bash
   npm run dev
   ```

5. **Open your browser**
   Navigate to `http://localhost:5173`

## 🔧 Environment Variables

The application uses secure environment variable management. Required secrets:

- `GOOGLE_GEMINI_API_KEY`: Your Google Gemini API key for AI content generation

## 📁 Project Structure

```
src/
├── components/
│   ├── auth/                 # Authentication components
│   ├── layout/              # Layout and navigation
│   ├── prompt-builder/      # Core listing generation features
│   └── ui/                  # Reusable UI components (shadcn/ui)
├── hooks/                   # Custom React hooks
├── integrations/            # Third-party integrations (Supabase)
├── services/               # API services and backend logic
└── pages/                  # Main application pages
```

## 🎯 Core Components

- **PromptBuilder**: Main interface for creating property listings
- **PhotoUploadSection**: Drag-and-drop photo uploads with analysis
- **MinimalPhotoSorting**: AI-powered photo sequencing
- **SessionManager**: Manage multiple property listing sessions
- **GoogleIntegration**: Import data from Google Forms/Drive

## 🤖 AI Features

### Photo Analysis
- Automatically categorizes photos (exterior, kitchen, living, bedroom, etc.)
- Identifies room types and features
- Provides quality scores and confidence ratings
- Generates descriptive text for each photo

### Content Generation
- Creates TREB-compliant MLS descriptions
- Generates property walkthrough narratives
- Populates structured MLS data fields
- Adapts content for different property types

### Smart Modifications
- Luxury emphasis for high-end properties
- Family-focused content for residential homes
- Investment-oriented descriptions for rental properties
- Emotional appeal for lifestyle marketing

## 🚀 Deployment

### Via Lovable Platform
1. Visit your [Lovable project dashboard](https://lovable.dev)
2. Click **Share → Publish**
3. Your app will be deployed automatically

### Custom Domain
1. Navigate to **Project → Settings → Domains**
2. Click **Connect Domain**
3. Follow the setup instructions

## 🔐 Security

- All API keys are securely encrypted and managed
- User authentication via Google OAuth
- Secure file upload and processing
- Data validation with Zod schemas

## 📄 License

This project is proprietary software. All rights reserved.

## 🤝 Support

For support and questions, please contact the development team or visit the project documentation.