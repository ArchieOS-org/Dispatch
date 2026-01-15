//
//  MockAIService.swift
//  Dispatch
//
//  Mock AI service for generating listing descriptions.
//  PHASE 3: Replace with real Vercel AI backend integration.
//

import Foundation

// MARK: - AIServiceProtocol

/// Protocol for AI description generation services.
/// PHASE 3: Replace with real Vercel AI backend
protocol AIServiceProtocol: Sendable {
  /// Generate a property description based on input text.
  /// - Parameter input: Property information (address, type, details)
  /// - Returns: Generated marketing description
  func generateDescription(for input: String) async throws -> String

  /// Generate dual A/B outputs for comparison.
  /// PHASE 3: Real AI will generate two distinct versions
  func generateDualOutput(
    photos: [UploadedPhoto],
    documents: [UploadedDocument],
    propertyDetails: PropertyDetails
  ) async throws -> (outputA: GeneratedOutput, outputB: GeneratedOutput)

  /// Refine an existing output based on user prompt.
  /// PHASE 3: Real AI will apply refinement instructions
  func refineOutput(
    currentOutput: GeneratedOutput,
    prompt: String
  ) async throws -> GeneratedOutput
}

// MARK: - PropertyDetails

/// Property details for AI generation input.
struct PropertyDetails: Sendable {
  let address: String
  let propertyType: String?
  let city: String?
  let price: Decimal?
  let additionalDetails: String?

  init(
    address: String,
    propertyType: String? = nil,
    city: String? = nil,
    price: Decimal? = nil,
    additionalDetails: String? = nil
  ) {
    self.address = address
    self.propertyType = propertyType
    self.city = city
    self.price = price
    self.additionalDetails = additionalDetails
  }
}

// MARK: - AIServiceError

/// Errors that can occur during AI generation
enum AIServiceError: LocalizedError {
  case emptyInput
  case generationFailed(String)
  case networkUnavailable

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .emptyInput:
      return "Please provide property information to generate a description."
    case .generationFailed(let reason):
      return "Generation failed: \(reason)"
    case .networkUnavailable:
      return "Unable to connect to AI service. Please check your connection."
    }
  }
}

// MARK: - MockAIService

/// Mock implementation of AIServiceProtocol for development and testing.
/// Simulates realistic AI response times and generates plausible descriptions.
/// PHASE 3: Replace with real Vercel AI backend
final class MockAIService: AIServiceProtocol, Sendable {

  // MARK: Lifecycle

  init(simulatedDelay: Duration = .seconds(2)) {
    self.simulatedDelay = simulatedDelay
  }

  // MARK: Internal

  func generateDescription(for input: String) async throws -> String {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AIServiceError.emptyInput
    }

    // PHASE 3: Replace with real API call to Vercel AI backend
    // Simulate realistic AI processing time (2-3 seconds)
    try await Task.sleep(for: simulatedDelay)

    // Parse input to extract property details
    let address = extractValue(from: input, key: "Address") ?? "This exceptional property"
    let propertyType = extractValue(from: input, key: "Type") ?? extractValue(from: input, key: "Property Type")
    let city = extractValue(from: input, key: "City")

    // Generate a plausible mock description based on property type
    return generateMockDescription(
      address: address,
      propertyType: propertyType,
      city: city
    )
  }

  /// Generate dual A/B outputs for comparison.
  /// PHASE 3: Replace with real Vercel AI backend
  func generateDualOutput(
    photos: [UploadedPhoto],
    documents: [UploadedDocument],
    propertyDetails: PropertyDetails
  ) async throws -> (outputA: GeneratedOutput, outputB: GeneratedOutput) {
    // PHASE 3: Replace with real API call to Vercel AI backend
    // Simulate realistic AI processing time (3-4 seconds for dual output)
    try await Task.sleep(for: .seconds(3))

    let address = propertyDetails.address
    let mlsFieldsA = createMockMLSFields(address: address, tone: .a)
    let mlsFieldsB = createMockMLSFields(address: address, tone: .b)

    let outputA = GeneratedOutput(
      version: .a,
      mlsFields: mlsFieldsA,
      isSelected: false
    )

    let outputB = GeneratedOutput(
      version: .b,
      mlsFields: mlsFieldsB,
      isSelected: false
    )

    return (outputA, outputB)
  }

  /// Refine an existing output based on user prompt.
  /// PHASE 3: Replace with real Vercel AI backend
  func refineOutput(
    currentOutput: GeneratedOutput,
    prompt: String
  ) async throws -> GeneratedOutput {
    guard !prompt.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw AIServiceError.emptyInput
    }

    // PHASE 3: Replace with real API call to Vercel AI backend
    // Simulate refinement processing time (2 seconds)
    try await Task.sleep(for: .seconds(2))

    // Mock refinement: modify text based on prompt keywords
    var refinedFields = currentOutput.mlsFields
    refinedFields = applyMockRefinement(to: refinedFields, prompt: prompt)

    return GeneratedOutput(
      id: UUID(),
      version: currentOutput.version,
      mlsFields: refinedFields,
      generatedAt: Date(),
      isSelected: currentOutput.isSelected
    )
  }

  // MARK: Private

  private let simulatedDelay: Duration

  /// Apply mock refinement based on prompt keywords.
  /// PHASE 3: Real AI will apply sophisticated refinement
  private func applyMockRefinement(to fields: MLSFields, prompt: String) -> MLSFields {
    var refined = fields
    let lowercasePrompt = prompt.lowercased()

    // Mock refinement based on common keywords
    if lowercasePrompt.contains("luxur") {
      refined.headline = "Exquisite Luxury Estate in Premier Location"
      refined.tagline = "Unparalleled elegance awaits the discerning buyer"
      refined.publicRemarks = refined.publicRemarks
        .replacingOccurrences(of: "beautiful", with: "magnificent")
        .replacingOccurrences(of: "nice", with: "exceptional")
        .replacingOccurrences(of: "good", with: "premium")
    }

    if lowercasePrompt.contains("view") {
      refined.publicRemarks += "\n\nThe breathtaking views from this property must be seen to be believed, " +
        "offering panoramic vistas that change with every season."
    }

    if lowercasePrompt.contains("short") || lowercasePrompt.contains("concise") {
      // Truncate descriptions
      if refined.publicRemarks.count > 300 {
        let index = refined.publicRemarks.index(refined.publicRemarks.startIndex, offsetBy: 300)
        refined.publicRemarks = String(refined.publicRemarks[..<index]) + "..."
      }
    }

    if lowercasePrompt.contains("family") {
      refined.tagline = "The perfect place for your family to grow and thrive"
      refined.publicRemarks += "\n\nWith spacious bedrooms, a large backyard, and proximity to top-rated schools, " +
        "this home is ideal for families of all sizes."
    }

    if lowercasePrompt.contains("outdoor") || lowercasePrompt.contains("backyard") {
      refined.publicRemarks += "\n\nThe expansive outdoor living space is perfect for entertaining, " +
        "featuring a covered patio, mature landscaping, and room for a pool."
    }

    if lowercasePrompt.contains("invest") {
      refined.tagline = "An exceptional investment opportunity in a high-growth area"
      refined.privateRemarks += " Strong rental potential with historically appreciating values in this neighborhood."
    }

    return refined
  }

  /// Create mock MLS fields with different tones.
  /// PHASE 3: Real AI will generate unique content
  private func createMockMLSFields(address: String, tone: OutputVersion) -> MLSFields {
    var fields = MLSFields()

    // Property details (same for both tones)
    fields.propertyType = "Single Family"
    fields.yearBuilt = "2015"
    fields.squareFootage = "2,450"
    fields.lotSize = "0.25 acres"
    fields.bedrooms = "4"
    fields.bathrooms = "2.5"
    fields.stories = "2"
    fields.parkingSpaces = "2"
    fields.garageType = "Attached 2-Car"

    // Features (same for both tones)
    fields.heatingCooling = "Central Air, Forced Air"
    fields.flooring = "Hardwood, Tile, Carpet"
    fields.appliances = "Stainless Steel Refrigerator, Dishwasher, Microwave, Gas Range"
    fields.exteriorFeatures = "Covered Patio, Fenced Yard, Sprinkler System"
    fields.interiorFeatures = "Fireplace, High Ceilings, Walk-in Closets"
    fields.communityFeatures = "Pool, Tennis Courts, Playground"

    // Tone-specific content
    switch tone {
    case .a:
      // Professional & Formal
      fields.headline = "Exceptional Residence in Prime Location"
      fields.tagline = "Sophisticated living meets modern convenience"
      fields.publicRemarks = """
        This meticulously maintained \(fields.bedrooms)-bedroom, \(fields.bathrooms)-bathroom residence \
        at \(address) offers \(fields.squareFootage) square feet of refined living space. \
        Built in \(fields.yearBuilt), this two-story home features premium finishes throughout, \
        including hardwood flooring, high ceilings, and a gas fireplace.

        The gourmet kitchen is equipped with stainless steel appliances and ample counter space. \
        The primary suite includes a spa-like bathroom and generous walk-in closet. \
        Additional amenities include a \(fields.garageType.lowercased()) garage, covered patio, \
        and professionally landscaped yard with sprinkler system.

        Community features include pool, tennis courts, and playground access. \
        This property represents an exceptional opportunity for discerning buyers.
        """
      fields.privateRemarks = "Seller motivated. Pre-approved buyers preferred. Showing notice: 24 hours."
      fields.directions = "From Main St, turn east on Oak Ave, property on right after 0.5 miles."

    case .b:
      // Warm & Inviting
      fields.headline = "Welcome Home to Your Dream Property"
      fields.tagline = "Where memories are made and families thrive"
      fields.publicRemarks = """
        Imagine coming home to this beautiful \(fields.bedrooms)-bedroom, \(fields.bathrooms)-bathroom \
        family home at \(address)! With \(fields.squareFootage) square feet of warm, inviting living space, \
        there's room for everyone to spread out and make themselves at home.

        You'll love gathering in the heart of the home - a sun-drenched kitchen with all the modern \
        amenities you need to create delicious meals for family and friends. Cozy up by the fireplace \
        on chilly evenings, or step outside to your covered patio and fenced backyard - perfect for \
        barbecues, playtime, and making memories.

        The community offers amazing amenities including a sparkling pool, tennis courts, and playground. \
        This isn't just a house - it's the place where your family story continues. Come see it today!
        """
      fields.privateRemarks = "Sellers are relocating and flexible on timing. Family-friendly neighborhood."
      fields.directions = "Head east on Main St, turn right onto Oak Ave. Look for the welcoming front porch!"
    }

    return fields
  }

  private func extractValue(from input: String, key: String) -> String? {
    let lines = input.components(separatedBy: "\n")
    for line in lines {
      if line.lowercased().hasPrefix(key.lowercased() + ":") {
        let value = line.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
      }
    }
    return nil
  }

  private func generateMockDescription(
    address: String,
    propertyType: String?,
    city: String?
  ) -> String {
    let locationPhrase = city.map { "in the heart of \($0)" } ?? "in this sought-after neighborhood"

    switch propertyType?.lowercased() {
    case "sale":
      return """
      Welcome to \(address), a stunning residence \(locationPhrase) that perfectly blends modern elegance with timeless comfort.

      Step inside to discover an open-concept living space bathed in natural light, featuring hardwood floors throughout and designer finishes at every turn. The gourmet kitchen boasts premium appliances, quartz countertops, and a spacious island perfect for entertaining.

      The primary suite offers a serene retreat with a spa-inspired ensuite bathroom and generous walk-in closet. Additional bedrooms provide flexibility for family, guests, or a home office.

      Outside, enjoy your private outdoor space ideal for morning coffee or evening gatherings. This home represents an exceptional opportunity for discerning buyers seeking quality, location, and lifestyle.

      Schedule your private showing today.
      """

    case "lease", "rental":
      return """
      Now available for lease: \(address), a beautifully appointed residence \(locationPhrase).

      This move-in ready home features an inviting open floor plan with abundant natural light and contemporary finishes throughout. The fully equipped kitchen includes modern appliances and ample storage, while the living areas offer the perfect setting for both relaxation and entertaining.

      The comfortable bedrooms provide peaceful retreats, with the primary suite featuring its own ensuite bathroom. Enjoy the convenience of in-unit laundry and dedicated parking.

      Ideally situated near shopping, dining, and major transit routes, this property offers the perfect combination of comfort and convenience.

      Contact us today to schedule a viewing.
      """

    case "pre-listing":
      return """
      Coming Soon: \(address), an exceptional property \(locationPhrase).

      This highly anticipated listing will offer buyers a rare opportunity to own a meticulously maintained home in one of the area's most desirable locations. With thoughtful updates throughout and move-in ready condition, this property is expected to generate significant interest.

      Pre-qualified buyers are encouraged to register their interest early for priority viewing access.

      Stay tuned for full details and photos. This one won't last long.
      """

    default:
      return """
      Discover \(address), a remarkable property \(locationPhrase) offering exceptional value and lifestyle appeal.

      This well-maintained home presents an ideal opportunity for those seeking quality living in a prime location. The thoughtfully designed layout maximizes space and natural light, while quality finishes throughout reflect pride of ownership.

      Whether you're looking for a place to call home or an investment opportunity, this property deserves your attention.

      Contact us today for more information or to arrange a private showing.
      """
    }
  }
}
