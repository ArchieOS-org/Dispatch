//
//  DesignSystemBridge.swift
//  Dispatch
//
//  Bridge file for DesignSystem package.
//  Re-exports all DesignSystem types to maintain backward compatibility
//  with existing DS.* references throughout the app.
//
//  During migration, both the package and local DS enums coexist.
//  The local Design/*.swift files can be gradually removed as
//  their functionality is migrated to the DesignSystem package.
//

// Re-export the entire DesignSystem module
// This makes all public types from DesignSystem available without
// requiring explicit imports in each file.
@_exported import DesignSystem
