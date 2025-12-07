//
//  RealtimeSyncable.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

/// Protocol for models that sync with Supabase.
/// ConflictStrategy is defined in Enums/ConflictStrategy.swift
protocol RealtimeSyncable {
    var syncedAt: Date? { get set }
    var isDirty: Bool { get }
    var conflictResolution: ConflictStrategy { get }
}

extension RealtimeSyncable {
    /// Default conflict resolution strategy
    var conflictResolution: ConflictStrategy {
        .lastWriteWins
    }
}
