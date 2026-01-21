# SwiftLint cleanup list

Generated from `swiftlint lint Dispatch --config .swiftlint.yml --reporter json`.
Non-trivial fixes are listed for follow-up; no refactors applied.

| File | Line | Rule | Suggested fix |
| --- | --- | --- | --- |
| Dispatch/App/ContentView.swift | 47 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/App/State/AppState.swift | 94 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/App/State/SyncCoordinator.swift | 86 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/App/State/SyncCoordinator.swift | 103 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Debug/DebugLogger.swift | 79 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Design/Shared/Components/FloatingActionButton.swift | 54 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Design/Shared/Components/OverflowMenu.swift | 107 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Design/Shared/Components/OverflowMenu.swift | 110 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Design/Shared/Components/OverflowMenu.swift | 113 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Design/Shared/Components/OverflowMenu.swift | 130 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Design/Shared/Components/SidebarMenuRow.swift | 45 | `empty_count` | Use `isEmpty` or `!isEmpty` instead of `count == 0`. |
| Dispatch/Design/Shared/Components/SidebarMenuRow.swift | 54 | `empty_count` | Use `isEmpty` or `!isEmpty` instead of `count == 0`. |
| Dispatch/Features/Listings/Views/Components/StageCardsGrid.swift | 52 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/Listings/Views/Components/StageCardsSection.swift | 38 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/Listings/Views/Components/StagePicker.swift | 102 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/Listings/Views/Screens/ListingDetailView.swift | 50 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Features/Listings/Views/Screens/ListingDetailView.swift | 443 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Features/Listings/Views/Screens/ListingDetailView.swift | 453 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Features/Listings/Views/Screens/ListingListView.swift | 69 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Features/Listings/Views/Screens/ListingListView.swift | 111 | `implicit_return` | Add an explicit `return` or expand the body to satisfy style. |
| Dispatch/Features/Listings/Views/Sheets/AddListingSheet.swift | 229 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/Properties/Views/Screens/PropertiesListView.swift | 81 | `implicit_return` | Add an explicit `return` or expand the body to satisfy style. |
| Dispatch/Features/Search/Views/Components/SearchOverlay.swift | 160 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/Settings/Views/ActivityTemplateEditorView.swift | 221 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Features/Settings/Views/ListingTypeDetailView.swift | 223 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Features/WorkItems/State/WorkItemActions.swift | 33 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Features/WorkItems/Views/Components/Notes/NotesSection.swift | 287 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/WorkItems/Views/Components/Notes/NotesSection.swift | 288 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/WorkItems/Views/Components/Notes/NotesSection.swift | 298 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/WorkItems/Views/Components/Notes/NotesSection.swift | 310 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/WorkItems/Views/Components/Notes/NotesSection.swift | 311 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/WorkItems/Views/Components/WorkItem/WorkItemRow.swift | 104 | `unused_optional_binding` | Remove the unused binding or use `if value != nil`. |
| Dispatch/Features/WorkItems/Views/Sheets/AddSubtaskSheet.swift | 67 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift | 241 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift | 250 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Networking/Supabase/SupabaseClient.swift | 19 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Networking/Supabase/SupabaseClient.swift | 20 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Networking/Supabase/SupabaseClient.swift | 21 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Networking/Supabase/SupabaseClient.swift | 29 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Networking/Supabase/SupabaseClient.swift | 48 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Networking/Supabase/SupabaseClient.swift | 49 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Networking/Supabase/SupabaseClient.swift | 50 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Networking/Supabase/SupabaseClient.swift | 51 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Persistence/Sync/SyncManager.swift | 368 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Foundation/Persistence/Sync/SyncManager.swift | 781 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Persistence/Sync/SyncManager.swift | 2165 | `modifier_order` | Reorder modifiers to match the style guide. |
| Dispatch/Foundation/Platform/macOS/BottomToolbar.swift | 183 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Platform/macOS/BottomToolbar.swift | 184 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Platform/macOS/BottomToolbar.swift | 195 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Platform/macOS/BottomToolbar.swift | 196 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/PreviewDataFactory.swift | 15 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Foundation/Testing/PreviewDataFactory.swift | 16 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Foundation/Testing/PreviewDataFactory.swift | 17 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 40 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 56 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 72 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 88 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 106 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 124 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 142 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 171 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 188 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 205 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 216 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 225 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 227 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 237 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 239 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 249 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 251 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/SupabaseTestHelpers.swift | 255 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| Dispatch/Foundation/Testing/TestDataFactory.swift | 252 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Views/Deprecated/ActivityListView.swift | 74 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| Dispatch/Views/Deprecated/TaskListView.swift | 75 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/DTOTests.swift | 37 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/DTOTests.swift | 149 | `empty_string` | Use `.isEmpty` instead of `== ""`. |
| DispatchTests/DTOTests.swift | 230 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/DTOTests.swift | 321 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/DTOTests.swift | 382 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/DTOTests.swift | 460 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/DTOTests.swift | 489 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/DTOTests.swift | 540 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/DTOTests.swift | 590 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/EnumTests.swift | 91 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/PreviewTests/PreviewInfrastructureTests.swift | 32 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/RLSIntegrationTests.swift | 25 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/RLSIntegrationTests.swift | 26 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/RLSIntegrationTests.swift | 27 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/State/AppStateTests.swift | 15 | `implicitly_unwrapped_optional` | Use a non-optional with proper initialization or unwrap safely. |
| DispatchTests/SyncCoalescingTests.swift | 28 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| DispatchTests/SyncCoalescingTests.swift | 47 | `no_direct_standard_out_logs` | Replace print/debugPrint with Logger/os_log or remove (DEBUG-only if needed). |
| DispatchTests/SyncRelationshipTests.swift | 15 | `implicitly_unwrapped_optional` | Use a non-optional with proper initialization or unwrap safely. |
| DispatchTests/SyncRelationshipTests.swift | 16 | `implicitly_unwrapped_optional` | Use a non-optional with proper initialization or unwrap safely. |
| DispatchTests/SyncRelationshipTests.swift | 17 | `implicitly_unwrapped_optional` | Use a non-optional with proper initialization or unwrap safely. |
| DispatchTests/UtilityTests.swift | 115 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/UtilityTests.swift | 116 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/UtilityTests.swift | 127 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/UtilityTests.swift | 137 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/UtilityTests.swift | 146 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/UtilityTests.swift | 147 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/UtilityTests.swift | 148 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/UtilityTests.swift | 178 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/UtilityTests.swift | 182 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/UtilityTests.swift | 186 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
| DispatchTests/UtilityTests.swift | 190 | `force_unwrapping` | Use guard/if let or provide a default instead of `!`. |
