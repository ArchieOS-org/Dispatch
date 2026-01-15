//
//  MockAIService.swift
//  Dispatch
//
//  Mock AI service for generating listing descriptions.
//  PHASE 2: Replace with real Vercel AI backend integration.
//

import Foundation

// MARK: - AIServiceProtocol

/// Protocol for AI description generation services.
/// PHASE 2: Replace with real Vercel AI backend
protocol AIServiceProtocol: Sendable {
  /// Generate a property description based on input text.
  /// - Parameter input: Property information (address, type, details)
  /// - Returns: Generated marketing description
  func generateDescription(for input: String) async throws -> String
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
/// PHASE 2: Replace with real Vercel AI backend
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

    // PHASE 2: Replace with real API call to Vercel AI backend
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

  // MARK: Private

  private let simulatedDelay: Duration

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
