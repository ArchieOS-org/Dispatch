# Dispatch Design System

Technical reference for the design token system used throughout the app.

## Architecture Overview

```mermaid
graph TD
    DS[DS Namespace] --> Colors[DS.Colors]
    DS --> Typography[DS.Typography]
    DS --> Spacing[DS.Spacing]
    DS --> Shadows[DS.Shadows]
    DS --> Icons[DS.Icons]

    Colors --> PriorityColors[PriorityColors]
    Colors --> Status[Status]
    Colors --> Sync[Sync]
    Colors --> Claim[Claim]
    Colors --> Background[Background]
    Colors --> Text[Text]

    Icons --> SyncIcons[Sync]
    Icons --> StatusIcons[StatusIcons]
    Icons --> ClaimIcons[Claim]
    Icons --> Action[Action]
    Icons --> Navigation[Navigation]
    Icons --> Entity[Entity]
    Icons --> ActivityTypeIcons[ActivityType]
    Icons --> Alert[Alert]
    Icons --> Time[Time]
```

## File Structure

```
Dispatch/Design/
├── DesignSystem.swift      # Main DS namespace declaration
├── ColorSystem.swift       # DS.Colors - semantic colors
├── Typography.swift        # DS.Typography - font styles
├── Spacing.swift          # DS.Spacing - 4pt grid system
├── Shadows.swift          # DS.Shadows - elevation styles
└── IconSystem.swift       # DS.Icons - SF Symbol tokens
```

## Usage Pattern

All tokens accessed via `DS` namespace:

```swift
// Colors
DS.Colors.PriorityColors.color(for: .high)  // Orange
DS.Colors.Status.color(for: .completed)     // Green
DS.Colors.Background.primary                 // System background
DS.Colors.Text.secondary                     // Dimmed text

// Typography
DS.Typography.headline                       // Card titles
DS.Typography.body                           // Content text
DS.Typography.caption                        // Timestamps

// Spacing
DS.Spacing.md                               // 12pt default
DS.Spacing.cardPadding                      // 12pt
DS.Spacing.radiusCard                       // 10pt

// Shadows
.dsShadow(DS.Shadows.card)                  // Card elevation
DS.Shadows.notesOverflowGradient            // Notes stack gradient

// Icons
DS.Icons.Action.add                         // "plus"
DS.Icons.Entity.task                        // "checkmark.square"
DS.Icons.StatusIcons.icon(for: .completed)  // "checkmark.circle.fill"
```

---

## Colors (DS.Colors)

### Priority Colors

| Token | Value | Usage |
|-------|-------|-------|
| `PriorityColors.low` | Gray | Low priority indicator |
| `PriorityColors.medium` | Blue | Medium priority indicator |
| `PriorityColors.high` | Orange | High priority indicator |
| `PriorityColors.urgent` | Red | Urgent priority indicator |

**Helper:** `DS.Colors.PriorityColors.color(for: Priority) -> Color`

### Status Colors

| Token | Value | Usage |
|-------|-------|-------|
| `Status.open` | Blue | Open/new items |
| `Status.inProgress` | Orange | In progress items |
| `Status.completed` | Green | Completed items |
| `Status.deleted` | Gray (50% opacity) | Deleted items |

**Helpers:**
- `DS.Colors.Status.color(for: TaskStatus) -> Color`
- `DS.Colors.Status.color(for: ActivityStatus) -> Color`

### Sync Colors

| Token | Value | Usage |
|-------|-------|-------|
| `Sync.synced` | Green | Successfully synced |
| `Sync.syncing` | Blue | Currently syncing |
| `Sync.pending` | Orange | Pending sync |
| `Sync.error` | Red | Sync error |

**Helper:** `DS.Colors.Sync.color(for: SyncStatus) -> Color`

### Claim Colors

| Token | Value | Usage |
|-------|-------|-------|
| `Claim.unclaimed` | Gray | Available to claim |
| `Claim.claimedByMe` | Green | Claimed by current user |
| `Claim.claimedByOther` | Orange | Claimed by another user |

**Helper:** `DS.Colors.Claim.color(for: ClaimState) -> Color`

### Background Colors (Adaptive)

| Token | UIKit Equivalent | Usage |
|-------|------------------|-------|
| `Background.primary` | systemBackground | Main background |
| `Background.secondary` | secondarySystemBackground | Subtle sections |
| `Background.tertiary` | tertiarySystemBackground | Deeper sections |
| `Background.grouped` | systemGroupedBackground | Grouped content |
| `Background.card` | systemGray6 | Card backgrounds |
| `Background.cardDark` | systemGray5 | Darker cards |

### Text Colors (Adaptive)

| Token | Usage |
|-------|-------|
| `Text.primary` | Main content |
| `Text.secondary` | Dimmed labels |
| `Text.tertiary` | More dimmed |
| `Text.quaternary` | Most dimmed |
| `Text.disabled` | Disabled state |
| `Text.placeholder` | Placeholder text |

### UI Element Colors

| Token | Value | Usage |
|-------|-------|-------|
| `accent` | accentColor | App accent |
| `destructive` | Red | Delete actions |
| `success` | Green | Success states |
| `warning` | Orange | Warning states |
| `info` | Blue | Info states |
| `border` | Gray 20% | Standard borders |
| `borderFocused` | accentColor | Focused borders |
| `separator` | systemSeparator | Dividers |
| `overdue` | Red | Overdue items |
| `dueSoon` | Orange | Due within 24h |
| `dueNormal` | Secondary | Normal due dates |

---

## Typography (DS.Typography)

### Hierarchy

```mermaid
graph LR
    subgraph Titles
        LT[largeTitle 32pt bold]
        T[title 22pt semibold]
        T3[title3 20pt semibold]
        H[headline 17pt semibold]
    end

    subgraph Body
        B[body 17pt]
        BS[bodySecondary 15pt]
        C[callout 16pt]
    end

    subgraph Captions
        CAP[caption 12pt]
        CAP2[captionSecondary 11pt]
        FN[footnote 13pt]
    end

    subgraph Monospace
        M[mono body]
        MC[monoCaption]
        MS[monoSmall]
    end
```

### All Tokens

| Token | Size | Weight | Usage |
|-------|------|--------|-------|
| `largeTitle` | 32pt | Bold | Screen titles |
| `title` | 22pt | Semibold | Section headers |
| `title3` | 20pt | Semibold | Subsections |
| `headline` | 17pt | Semibold | Card titles, list items |
| `body` | 17pt | Regular | Primary content |
| `bodySecondary` | 15pt | Regular | Secondary content |
| `callout` | 16pt | Regular | Emphasized body |
| `caption` | 12pt | Regular | Timestamps, metadata |
| `captionSecondary` | 11pt | Regular | Smaller metadata |
| `footnote` | 13pt | Regular | Notes, hints |
| `mono` | Body | Monospaced | Code, IDs |
| `monoCaption` | Caption | Monospaced | Small technical text |
| `monoSmall` | Caption2 | Monospaced | Debug logs |
| `detailLargeTitle` | 32pt | Bold | Detail view titles |
| `detailCollapsedTitle` | 18pt | Semibold | Collapsed headers |

---

## Spacing (DS.Spacing)

### Base Scale (4pt Grid)

| Token | Value | Usage |
|-------|-------|-------|
| `xxs` | 2pt | Extra extra small |
| `xs` | 4pt | Extra small |
| `sm` | 8pt | Small |
| `md` | 12pt | Medium (default) |
| `lg` | 16pt | Large |
| `xl` | 20pt | Extra large |
| `xxl` | 24pt | Extra extra large |
| `xxxl` | 32pt | Maximum |

### Component Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `cardPadding` | 12pt | Internal card padding |
| `sectionSpacing` | 20pt | Between sections |
| `stackSpacing` | 12pt | Stacked items |

### Notes Section

| Token | Value | Usage |
|-------|-------|-------|
| `notesStackHeight` | 140pt | Notes container height |
| `noteInputMinHeight` | 80pt | TextEditor min height |
| `noteInputMaxHeight` | 200pt | TextEditor max height |
| `shadowGradientHeight` | 12pt | Gradient overlay |
| `noteCascadeOffset` | 8pt | Cascading card offset |

### Avatar Sizes

| Token | Value | Usage |
|-------|-------|-------|
| `avatarSmall` | 24pt | Inline with text |
| `avatarMedium` | 32pt | List items |
| `avatarLarge` | 44pt | Detail views |

### Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| `radiusSmall` | 4pt | Subtle rounding |
| `radiusMedium` | 8pt | Cards, buttons |
| `radiusLarge` | 16pt | Modals, sheets |
| `radiusCard` | 10pt | Standard cards |

### Touch Targets

| Token | Value | Usage |
|-------|-------|-------|
| `minTouchTarget` | 44pt | Apple HIG minimum |
| `priorityDotSize` | 8pt | Priority indicator |

---

## Shadows (DS.Shadows)

### Shadow Styles

```mermaid
graph TB
    subgraph Elevation
        N[none - 0pt]
        SU[subtle - 2pt]
        SM[small - 4pt]
        C[card - 6pt]
        M[medium - 8pt]
        E[elevated - 12pt]
        L[large - 16pt]
    end

    N --> SU --> SM --> C --> M --> E --> L
```

| Style | Radius | Y Offset | Opacity | Usage |
|-------|--------|----------|---------|-------|
| `none` | 0 | 0 | 0% | No shadow |
| `subtle` | 2pt | 1pt | 8% | Minimal |
| `small` | 4pt | 2pt | 8% | Buttons |
| `card` | 6pt | 2pt | 10% | Cards |
| `medium` | 8pt | 4pt | 12% | Floating |
| `elevated` | 12pt | 6pt | 15% | Modals |
| `large` | 16pt | 8pt | 20% | Overlays |

### Usage

```swift
// Apply via view modifier
.dsShadow(DS.Shadows.card)

// Gradients
DS.Shadows.notesOverflowGradient  // Top shadow for notes
DS.Shadows.bottomFadeGradient    // Bottom fade
```

---

## Icons (DS.Icons)

### Sync Icons

| Token | SF Symbol | Usage |
|-------|-----------|-------|
| `Sync.synced` | checkmark.icloud.fill | Success |
| `Sync.syncing` | arrow.triangle.2.circlepath.icloud | In progress |
| `Sync.pending` | icloud.and.arrow.up | Queued |
| `Sync.error` | exclamationmark.icloud.fill | Error |
| `Sync.offline` | icloud.slash | Offline |

### Status Icons

| Token | SF Symbol | Usage |
|-------|-----------|-------|
| `StatusIcons.open` | circle | New item |
| `StatusIcons.inProgress` | circle.lefthalf.filled | In progress |
| `StatusIcons.completed` | checkmark.circle.fill | Done |
| `StatusIcons.deleted` | trash.circle | Deleted |

### Claim Icons

| Token | SF Symbol | Usage |
|-------|-----------|-------|
| `Claim.unclaimed` | person.badge.plus | Available |
| `Claim.claimed` | person.fill.checkmark | Mine |
| `Claim.claimedByOther` | person.fill | Others |
| `Claim.release` | person.badge.minus | Release |

### Action Icons

| Token | SF Symbol | Usage |
|-------|-----------|-------|
| `Action.edit` | pencil | Edit |
| `Action.delete` | trash | Delete |
| `Action.add` | plus | Create |
| `Action.addCircle` | plus.circle.fill | FAB |
| `Action.save` | checkmark | Confirm |
| `Action.cancel` | xmark | Cancel |
| `Action.more` | ellipsis | Options |
| `Action.refresh` | arrow.clockwise | Reload |

### Navigation Icons

| Token | SF Symbol | Usage |
|-------|-----------|-------|
| `Navigation.back` | chevron.left | Back |
| `Navigation.forward` | chevron.right | Forward |
| `Navigation.close` | xmark | Dismiss |
| `Navigation.settings` | gearshape | Settings |
| `Navigation.search` | magnifyingglass | Search |
| `Navigation.filter` | line.3.horizontal.decrease.circle | Filter |

### Entity Icons

| Token | SF Symbol | Usage |
|-------|-----------|-------|
| `Entity.task` | checkmark.square | Task |
| `Entity.activity` | calendar | Activity |
| `Entity.listing` | house | Listing |
| `Entity.note` | note.text | Note |
| `Entity.subtask` | checklist | Subtask |
| `Entity.user` | person.circle | User |

### Activity Type Icons

| Token | SF Symbol | Usage |
|-------|-----------|-------|
| `ActivityType.call` | phone | Phone call |
| `ActivityType.email` | envelope | Email |
| `ActivityType.meeting` | person.2.circle | Meeting |
| `ActivityType.showProperty` | house.and.flag | Showing |
| `ActivityType.followUp` | arrow.uturn.backward.circle | Follow up |
| `ActivityType.other` | square.grid.2x2 | Other |

### Alert Icons

| Token | SF Symbol | Usage |
|-------|-----------|-------|
| `Alert.warning` | exclamationmark.triangle | Warning |
| `Alert.error` | xmark.octagon | Error |
| `Alert.info` | info.circle | Info |
| `Alert.success` | checkmark.circle | Success |
| `Alert.notification` | bell | Notification |

### Time Icons

| Token | SF Symbol | Usage |
|-------|-----------|-------|
| `Time.clock` | clock | Time |
| `Time.calendar` | calendar | Date |
| `Time.scheduled` | calendar.badge.clock | Scheduled |
| `Time.overdue` | clock.badge.exclamationmark | Overdue |
| `Time.timer` | timer | Duration |

---

## Best Practices

### DO

```swift
// Use semantic tokens
Text("Title").font(DS.Typography.headline)
Circle().fill(DS.Colors.PriorityColors.color(for: item.priority))
.padding(DS.Spacing.cardPadding)
.dsShadow(DS.Shadows.card)

// Use helper functions for enums
DS.Colors.Status.color(for: task.status)
DS.Icons.StatusIcons.icon(for: activity.status)
```

### DON'T

```swift
// Avoid hardcoded values
Text("Title").font(.headline)  // Use DS.Typography.headline
Circle().fill(.orange)          // Use DS.Colors.PriorityColors
.padding(12)                    // Use DS.Spacing.md
.shadow(radius: 6)              // Use .dsShadow(DS.Shadows.card)
```

### Performance Note

When using placeholder text in TextEditors, use opacity instead of conditional rendering to avoid layout thrashing:

```swift
// GOOD - stable layout
Text(placeholder)
    .opacity(text.isEmpty ? 1 : 0)

// BAD - causes layout recalculation
if text.isEmpty {
    Text(placeholder)
}
```
