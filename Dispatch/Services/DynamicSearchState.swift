//
//  DynamicSearchState.swift
//  Dispatch
//
//  Manages the dynamic search box state based on scroll position.
//  Created by Claude on 2025-12-23.
//

import SwiftUI
import Combine

/// Manages the state of the dynamic search box that changes appearance based on scroll position.
///
/// The search box has three states:
/// - `.default`: Gray search box at top
/// - `.pulled`: Gray search box moved down with arrow visible
/// - `.activated`: Blue search box and arrow when pulled further
@MainActor
final class DynamicSearchState: ObservableObject {
    
    // MARK: - Search Box States
    
    enum SearchBoxState: Equatable {
        case `default`  // Gray search box at top
        case pulled     // Gray search box moved down with arrow
        case activated  // Blue search box and arrow
    }
    
    // MARK: - Published Properties
    
    /// Current state of the search box
    @Published var currentState: SearchBoxState = .default
    
    /// Current scroll offset (positive when scrolled down)
    @Published var scrollOffset: CGFloat = 0
    
    /// Vertical offset for the search box position
    @Published var searchBoxOffset: CGFloat = 0
    
    /// Whether the dropdown arrow should be visible
    @Published var showArrow: Bool = false
    
    /// Whether the search box should use blue styling
    @Published var useBlueStyle: Bool = false
    
    // MARK: - Configuration
    
    /// Scroll distance to start showing the arrow and moving search box
    private let pullThreshold: CGFloat = 20
    
    /// Scroll distance to activate blue styling
    private let activationThreshold: CGFloat = 60
    
    /// Maximum offset for the search box
    private let maxSearchBoxOffset: CGFloat = 40
    
    // MARK: - State Management
    
    /// Updates the search box state based on scroll offset
    func updateScrollOffset(_ offset: CGFloat) {
        scrollOffset = offset
        updateSearchBoxState()
    }
    
    /// Updates the search box state and derived properties
    private func updateSearchBoxState() {
        let newState: SearchBoxState
        
        if scrollOffset >= activationThreshold {
            newState = .activated
        } else if scrollOffset >= pullThreshold {
            newState = .pulled
        } else {
            newState = .default
        }
        
        // Only update if state actually changed to avoid unnecessary animations
        if newState != currentState {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentState = newState
                updateDerivedProperties()
            }
        } else {
            // Update derived properties without animation for smooth scrolling
            updateDerivedProperties()
        }
    }
    
    /// Updates derived properties based on current state and scroll offset
    private func updateDerivedProperties() {
        switch currentState {
        case .default:
            searchBoxOffset = 0
            showArrow = false
            useBlueStyle = false
            
        case .pulled:
            // Gradually move search box down as user scrolls
            let progress = min((scrollOffset - pullThreshold) / (activationThreshold - pullThreshold), 1.0)
            searchBoxOffset = progress * maxSearchBoxOffset
            showArrow = true
            useBlueStyle = false
            
        case .activated:
            searchBoxOffset = maxSearchBoxOffset
            showArrow = true
            useBlueStyle = true
        }
    }
    
    /// Resets the search box to default state
    func reset() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentState = .default
            scrollOffset = 0
            updateDerivedProperties()
        }
    }
}
