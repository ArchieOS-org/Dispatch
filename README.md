# Dispatch

A Swift multi-platform app (iOS, iPadOS, macOS) with a Supabase backend.

## Getting Started

### Prerequisites

- Xcode 16+
- macOS 15.0+
- iOS 18.0+ (for simulators)

### Credential Setup

Dispatch requires Supabase credentials to connect to the backend. Credentials are loaded with this priority:

1. **Environment Variables** (CI/CD, production)
2. **SecretsConfig.plist** (local development)
3. **Placeholder values** (build validation only - app will not function)

#### Local Development Setup

1. Copy the example plist:
   ```bash
   cp Dispatch/App/Configuration/SecretsConfig.plist.example \
      Dispatch/App/Configuration/SecretsConfig.plist
   ```

2. Edit `SecretsConfig.plist` with your actual Supabase credentials:
   - `SUPABASE_URL`: Your Supabase project URL (e.g., `https://yourproject.supabase.co`)
   - `SUPABASE_ANON_KEY`: Your Supabase anonymous/public key

3. The plist is gitignored and will not be committed.

#### Where to Get Credentials

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to Settings > API
4. Copy:
   - **Project URL** for `SUPABASE_URL`
   - **anon public** key for `SUPABASE_ANON_KEY`

#### CI/CD Setup

Set these environment variables in your CI/CD pipeline:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The app will automatically use environment variables when they are present.

### Building

```bash
# iOS Simulator
xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# macOS
xcodebuild -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=macOS' build
```

### Testing

```bash
# Unit tests (iOS Simulator)
xcodebuild test -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Unit tests (macOS)
xcodebuild test -project Dispatch.xcodeproj -scheme Dispatch \
  -destination 'platform=macOS'
```

## Documentation

- `DESIGN_SYSTEM.md` - UI patterns and components
- `DATA_SYSTEM.md` - Data flow and Supabase patterns
- `CLAUDE.md` - AI agent instructions and architecture

## License

Proprietary - All rights reserved.
