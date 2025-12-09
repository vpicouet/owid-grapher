# Implementation Report: Independent Axis Control for "Display Average Annual Change" in OWID Scatter Plots

## Executive Summary

This report provides a comprehensive analysis for implementing independent axis control for the "Display average annual change" feature in Our World in Data (OWID) scatter plots. Currently, this feature applies to both X and Y axes simultaneously. The proposed enhancement would allow users to apply average annual change calculations independently to each axis, enabling powerful new analytical capabilities.

**Complexity Level**: Medium
**Risk Level**: Medium-Low
**Development Time Estimate**: 15-20 working days
**Rollback Feasibility**: High (changes are additive and backward compatible)

## Current System Analysis

### Current Implementation Overview

The existing "Display average annual change" functionality is controlled by:

1. **State Management**: The `showYearLabels` boolean property in `GrapherState`
2. **UI Control**: A single toggle in the admin interface (`EditorCustomizeTab.tsx`)
3. **Data Transformation**: The `isRelativeMode` computed property triggers `table.toAverageAnnualChangeForEachEntity()`
4. **Display Logic**: When enabled, both axes show percentage change per year with "%" formatting

### Key Code Locations

- **Core State**: `packages/@ourworldindata/grapher/src/core/GrapherState.tsx` (lines 254, 2462)
- **Admin UI**: `adminSiteClient/EditorCustomizeTab.tsx` (lines 430-432, 513-519)  
- **Scatter Logic**: `packages/@ourworldindata/grapher/src/scatterCharts/ScatterPlotChartState.ts` (lines 78-83)
- **Data Transform**: `packages/@ourworldindata/core-table/src/OwidTable.ts` (method `toAverageAnnualChangeForEachEntity`)

### Current Behavior Flow

1. User toggles "Always show year labels" (confusingly named)
2. `showYearLabels` boolean is set
3. For scatter plots, this becomes `isRelativeMode` 
4. `ScatterPlotChartState.transformedTable` calls `table.toAverageAnnualChangeForEachEntity([xColumnSlug, yColumnSlug])`
5. Both axes display percentage annual change with linear scale forced

## Proposed Enhancement Design

### New Properties Structure

```typescript
// Replace single boolean with more granular control
interface GrapherState {
    // Legacy property - keep for backward compatibility
    showYearLabels?: boolean
    
    // New properties for independent axis control
    xAxisAverageAnnualChange?: boolean
    yAxisAverageAnnualChange?: boolean
}
```

### Data Transformation Strategy

Instead of a single `toAverageAnnualChangeForEachEntity()` call for both columns, we need:

```typescript
// In ScatterPlotChartState.transformedTable
if (this.manager.xAxisAverageAnnualChange && this.manager.yAxisAverageAnnualChange) {
    // Both axes - current behavior
    table = table.toAverageAnnualChangeForEachEntity([this.xColumnSlug, this.yColumnSlug])
} else if (this.manager.xAxisAverageAnnualChange) {
    // X-axis only
    table = table.toAverageAnnualChangeForEachEntity([this.xColumnSlug])
} else if (this.manager.yAxisAverageAnnualChange) {
    // Y-axis only  
    table = table.toAverageAnnualChangeForEachEntity([this.yColumnSlug])
}
```

### UI/UX Design Options

#### Option A: Separate Checkboxes (Recommended)
```
□ X-axis: Display average annual change
□ Y-axis: Display average annual change
```

#### Option B: Dropdown Selection
```
Average annual change: [Dropdown]
- None (default)
- Both axes  
- X-axis only
- Y-axis only
```

**Recommendation**: Option A is more intuitive and allows independent toggling.

## Implementation Plan

### Phase 1: Core Infrastructure Changes (5-7 days)

#### 1.1 Type System Updates

**Files to modify:**
- `packages/@ourworldindata/types/src/grapherTypes/GrapherTypes.ts`
- `packages/@ourworldindata/grapher/src/schema/grapher-schema.009.yaml`

**Changes:**
```typescript
// Add new properties to GrapherInterface
interface GrapherInterface {
    // ... existing properties
    xAxisAverageAnnualChange?: boolean
    yAxisAverageAnnualChange?: boolean
}

// Update serialization keys
const grapherKeysToSerialize = [
    // ... existing keys
    "xAxisAverageAnnualChange",
    "yAxisAverageAnnualChange",
]
```

**Risk Level**: Low
**Complexity**: Simple property additions

#### 1.2 GrapherState Core Changes

**File**: `packages/@ourworldindata/grapher/src/core/GrapherState.tsx`

**Changes:**
```typescript
export class GrapherState {
    // Add new observable properties
    xAxisAverageAnnualChange: boolean | undefined = undefined
    yAxisAverageAnnualChange: boolean | undefined = undefined
    
    // Update makeObservable call
    constructor(options: GrapherProgrammaticInterface) {
        makeObservable(this, {
            // ... existing observables
            xAxisAverageAnnualChange: observable.ref,
            yAxisAverageAnnualChange: observable.ref,
        })
    }
    
    // Backward compatibility computed property
    @computed get isRelativeMode(): boolean {
        // Legacy behavior: if showYearLabels is set, apply to both axes
        if (this.showYearLabels !== undefined) {
            return this.showYearLabels && this.isOnScatterTab
        }
        // New behavior: either axis has average annual change
        return this.isOnScatterTab && (
            !!this.xAxisAverageAnnualChange || 
            !!this.yAxisAverageAnnualChange
        )
    }
    
    // New computed properties
    @computed get xAxisIsRelativeMode(): boolean {
        if (this.showYearLabels !== undefined) {
            return this.showYearLabels && this.isOnScatterTab
        }
        return this.isOnScatterTab && !!this.xAxisAverageAnnualChange
    }
    
    @computed get yAxisIsRelativeMode(): boolean {
        if (this.showYearLabels !== undefined) {
            return this.showYearLabels && this.isOnScatterTab  
        }
        return this.isOnScatterTab && !!this.yAxisAverageAnnualChange
    }
    
    // Update showYearLabelsToggleLabel for backward compatibility
    @computed get showYearLabelsToggleLabel(): string {
        if (this.isOnScatterTab) return "Display average annual change (legacy)"
        return "Always show year in labels for bar charts"
    }
}
```

**Risk Level**: Medium - Core state changes
**Complexity**: Medium - Requires careful backward compatibility

#### 1.3 Chart Manager Interface Updates

**File**: `packages/@ourworldindata/grapher/src/chart/ChartManager.ts`

```typescript
export interface ChartManager {
    // ... existing properties
    xAxisAverageAnnualChange?: boolean
    yAxisAverageAnnualChange?: boolean
    
    // Backward compatibility
    isRelativeMode?: boolean
}
```

**Risk Level**: Low
**Complexity**: Simple interface extension

### Phase 2: Scatter Plot Implementation (4-6 days)

#### 2.1 ScatterPlotChartState Updates

**File**: `packages/@ourworldindata/grapher/src/scatterCharts/ScatterPlotChartState.ts`

**Key Changes:**
```typescript
export class ScatterPlotChartState {
    @computed get transformedTable(): OwidTable {
        let table = this.transformedTableFromGrapher
        
        if (this.compareEndPointsOnly && !this.hasAnyRelativeMode) {
            table = table.keepMinTimeAndMaxTimeForEachEntityOnly()
        }
        
        // New: selective average annual change transformation
        if (this.hasAnyRelativeMode) {
            const columnsToTransform: string[] = []
            if (this.manager.xAxisAverageAnnualChange || this.legacyIsRelativeMode) {
                columnsToTransform.push(this.xColumnSlug)
            }
            if (this.manager.yAxisAverageAnnualChange || this.legacyIsRelativeMode) {
                columnsToTransform.push(this.yColumnSlug)
            }
            
            if (columnsToTransform.length > 0) {
                table = table.toAverageAnnualChangeForEachEntity(columnsToTransform)
            }
        }
        
        return table
    }
    
    @computed private get hasAnyRelativeMode(): boolean {
        return this.legacyIsRelativeMode || 
               !!this.manager.xAxisAverageAnnualChange || 
               !!this.manager.yAxisAverageAnnualChange
    }
    
    @computed private get legacyIsRelativeMode(): boolean {
        return !!this.manager.isRelativeMode
    }
    
    @computed get xScaleType(): ScaleType {
        const hasXRelative = this.manager.xAxisAverageAnnualChange || this.legacyIsRelativeMode
        return hasXRelative 
            ? ScaleType.linear 
            : (this.manager.xAxisConfig?.scaleType ?? ScaleType.linear)
    }
    
    @computed get yScaleType(): ScaleType {
        const hasYRelative = this.manager.yAxisAverageAnnualChange || this.legacyIsRelativeMode  
        return hasYRelative
            ? ScaleType.linear
            : (this.manager.yAxisConfig?.scaleType ?? ScaleType.linear)
    }
    
    @computed get horizontalAxisLabel(): string {
        const xAxisConfig = this.manager.xAxisConfig
        let label = xAxisConfig?.label || this.horizontalAxisLabelBase
        
        const hasXRelative = this.manager.xAxisAverageAnnualChange || this.legacyIsRelativeMode
        if (hasXRelative && label && label.length > 1) {
            label = `Average annual change in ${lowerCaseFirstLetterUnlessAbbreviation(label)}`
        }
        return label.trim()
    }
    
    @computed get verticalAxisLabel(): string {
        const yAxisConfig = this.manager.yAxisConfig
        let label = yAxisConfig?.label || this.yColumn?.displayName || ""
        
        const hasYRelative = this.manager.yAxisAverageAnnualChange || this.legacyIsRelativeMode
        if (hasYRelative && label && label.length > 1) {
            label = `Average annual change in ${lowerCaseFirstLetterUnlessAbbreviation(label)}`
        }
        return label.trim()
    }
}
```

**Risk Level**: Medium - Core chart logic changes
**Complexity**: Medium-High - Complex conditional logic

#### 2.2 Axis Configuration Updates

**Files**: 
- `packages/@ourworldindata/grapher/src/scatterCharts/ScatterPlotChartState.ts` (axis methods)
- `packages/@ourworldindata/grapher/src/scatterCharts/ScatterPlotChart.tsx` (formatting)

**Changes:**
```typescript
// In ScatterPlotChartState
toHorizontalAxis(config: AxisConfig): HorizontalAxis {
    const axis = config.toHorizontalAxis()
    axis.formatColumn = this.xColumn
    
    // Conditional scale type based on X-axis relative mode
    const hasXRelative = this.manager.xAxisAverageAnnualChange || this.legacyIsRelativeMode
    axis.scaleType = hasXRelative ? ScaleType.linear : this.xScaleType
    
    if (this.horizontalAxisLabel) axis.label = this.horizontalAxisLabel
    
    // Domain handling for mixed modes
    if (hasXRelative) {
        axis.domain = this.xDomainDefault // Force recalculation for relative values
    } else if (/* normal domain logic */) {
        axis.updateDomainPreservingUserSettings(this.xDomainDefault)
    }
    
    return axis
}

toVerticalAxis(config: AxisConfig): VerticalAxis {
    // Similar logic for Y-axis
}
```

**Risk Level**: Medium - Axis calculation changes
**Complexity**: Medium - Conditional domain and formatting logic

### Phase 3: Admin Interface Updates (3-4 days)

#### 3.1 Admin UI Component

**File**: `adminSiteClient/EditorCustomizeTab.tsx`

**Changes:**
```typescript
// In TimelineSection component
@action.bound onToggleXAxisAverageAnnualChange(value: boolean) {
    this.grapherState.xAxisAverageAnnualChange = value || undefined
    // Clear legacy property when using new controls
    if (value || this.grapherState.yAxisAverageAnnualChange) {
        this.grapherState.showYearLabels = undefined
    }
}

@action.bound onToggleYAxisAverageAnnualChange(value: boolean) {
    this.grapherState.yAxisAverageAnnualChange = value || undefined
    // Clear legacy property when using new controls  
    if (value || this.grapherState.xAxisAverageAnnualChange) {
        this.grapherState.showYearLabels = undefined
    }
}

render() {
    return (
        <Section name="Timeline selection">
            {/* ... existing timeline controls */}
            
            {/* New section for scatter plots */}
            {this.grapherState.isOnScatterTab && (
                <React.Fragment>
                    <h6>Average Annual Change (Scatter Plot)</h6>
                    <FieldsRow>
                        <Toggle
                            label="X-axis: Display average annual change"
                            value={!!grapherState.xAxisAverageAnnualChange}
                            onValue={this.onToggleXAxisAverageAnnualChange}
                        />
                        <Toggle
                            label="Y-axis: Display average annual change"
                            value={!!grapherState.yAxisAverageAnnualChange}
                            onValue={this.onToggleYAxisAverageAnnualChange}
                        />
                    </FieldsRow>
                    
                    {/* Legacy support warning */}
                    {!!grapherState.showYearLabels && (
                        <small className="form-text text-muted">
                            ⚠️ Using legacy "Always show year labels" setting. 
                            Use controls above for independent axis control.
                        </small>
                    )}
                </React.Fragment>
            )}
            
            {/* Existing year labels toggle - hide for scatter plots or show with warning */}
            {!this.grapherState.isOnScatterTab && (
                <FieldsRow>
                    <Toggle
                        label="Always show year labels"
                        value={!!grapherState.showYearLabels}
                        onValue={this.onToggleShowYearLabels}
                    />
                </FieldsRow>
            )}
        </Section>
    )
}
```

**Risk Level**: Low - UI changes only
**Complexity**: Low-Medium - Form logic with legacy compatibility

#### 3.2 Feature Detection

**File**: `adminSiteClient/EditorFeatures.tsx`

```typescript
@computed get scatterAxisIndependentAverageAnnualChange(): boolean {
    return this.grapherState.isOnScatterTab
}
```

**Risk Level**: Low
**Complexity**: Low

### Phase 4: Data Pipeline Updates (2-3 days)

#### 4.1 Core Table Method Enhancement

**File**: `packages/@ourworldindata/core-table/src/OwidTable.ts`

The existing `toAverageAnnualChangeForEachEntity()` method should handle partial column lists correctly. Review current implementation:

```typescript
toAverageAnnualChangeForEachEntity(columnSlugs: ColumnSlug[]): this {
    // Ensure method works correctly when only some columns are transformed
    // Current implementation should already handle this correctly
}
```

**Risk Level**: Low - Existing method should work
**Complexity**: Low - Verification only

#### 4.2 Migration Strategy

**File**: `db/migration/YYYYMMDDHHMMSS-AddIndependentAxisAverageAnnualChange.ts`

```typescript
export class AddIndependentAxisAverageAnnualChange implements MigrationInterface {
    public async up(queryRunner: QueryRunner): Promise<void> {
        // Add new columns to charts table
        await queryRunner.query(`
            ALTER TABLE charts 
            ADD COLUMN xAxisAverageAnnualChange TINYINT(1) NULL,
            ADD COLUMN yAxisAverageAnnualChange TINYINT(1) NULL
        `)
        
        // Migrate existing showYearLabels scatter plots
        await queryRunner.query(`
            UPDATE charts 
            SET 
                xAxisAverageAnnualChange = 1,
                yAxisAverageAnnualChange = 1
            WHERE 
                JSON_EXTRACT(config, '$.showYearLabels') = true
                AND JSON_EXTRACT(config, '$.chartTypes') LIKE '%ScatterPlot%'
        `)
    }
    
    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`
            ALTER TABLE charts 
            DROP COLUMN xAxisAverageAnnualChange,
            DROP COLUMN yAxisAverageAnnualChange
        `)
    }
}
```

**Risk Level**: Medium - Database migration
**Complexity**: Medium - JSON field manipulation

### Phase 5: Testing and Validation (3-4 days)

#### 5.1 Unit Tests

**Files to update:**
- `packages/@ourworldindata/grapher/src/scatterCharts/ScatterPlotChart.test.ts`
- `packages/@ourworldindata/grapher/src/core/GrapherState.test.ts`

**New test cases:**
```typescript
describe("independent axis average annual change", () => {
    it("calculates average annual change for X-axis only", () => {
        const chartState = new ScatterPlotChartState({
            manager: {
                ...manager,
                xAxisAverageAnnualChange: true,
                yAxisAverageAnnualChange: false,
            },
        })
        // Verify X values are transformed, Y values are not
    })
    
    it("calculates average annual change for Y-axis only", () => {
        // Similar test for Y-axis only
    })
    
    it("maintains backward compatibility with isRelativeMode", () => {
        // Test legacy behavior still works
    })
    
    it("handles mixed axis configurations correctly", () => {
        // Test axis labels, domains, formatting
    })
})
```

**Risk Level**: Low - Testing
**Complexity**: Medium - Comprehensive test coverage

#### 5.2 Integration Tests

**File**: `adminSiteClient/tests/EditorCustomizeTab.test.tsx`

```typescript
describe("Independent Axis Controls", () => {
    it("shows correct controls for scatter plots", () => {
        // Test UI rendering
    })
    
    it("updates state correctly when toggles change", () => {
        // Test state management
    })
    
    it("handles legacy compatibility warnings", () => {
        // Test backward compatibility UI
    })
})
```

**Risk Level**: Low - Testing
**Complexity**: Low-Medium - UI testing

## Risk Assessment and Mitigation

### Technical Risks

#### 1. Backward Compatibility Breakage
**Risk Level**: Medium
**Impact**: Existing charts could break or behave unexpectedly

**Mitigation Strategies:**
- Maintain `showYearLabels` property indefinitely
- Add computed properties that check legacy behavior first
- Comprehensive migration testing on staging environment
- Feature flags for gradual rollout

#### 2. Data Transformation Edge Cases
**Risk Level**: Medium
**Impact**: Incorrect calculations or missing data

**Mitigation Strategies:**
- Extensive testing with edge cases (zero values, negative values, single data points)
- Validation that `toAverageAnnualChangeForEachEntity()` handles partial column lists
- Performance testing with large datasets

#### 3. UI Complexity and User Confusion
**Risk Level**: Medium-Low
**Impact**: Users may not understand new controls

**Mitigation Strategies:**
- Clear labeling and help text
- Progressive disclosure (show advanced controls only when relevant)
- Documentation and training materials

#### 4. Performance Impact
**Risk Level**: Low
**Impact**: Additional computational overhead

**Mitigation Strategies:**
- Profile chart rendering performance
- Optimize conditional logic in hot paths
- Lazy computation where possible

### Compatibility Considerations

#### Frontend Compatibility
- **React Version**: Changes use existing patterns, no version conflicts expected
- **MobX Observables**: New properties follow existing observable patterns
- **TypeScript**: Proper type definitions prevent runtime errors

#### Backend Compatibility
- **Database Schema**: Additive changes only, no breaking modifications
- **API Endpoints**: No API changes required for this feature
- **Export Formats**: Charts should export correctly with mixed axis modes

#### Browser Compatibility
- **Modern Browsers**: No new browser features required
- **Performance**: Additional conditionals may have minimal performance impact
- **Accessibility**: Maintain existing accessibility features

## Testing Strategy

### Unit Testing (2 days)
```typescript
// ScatterPlotChartState.test.ts
describe("Mixed Axis Modes", () => {
    test("X-axis relative, Y-axis absolute", () => {
        const manager = {
            xAxisAverageAnnualChange: true,
            yAxisAverageAnnualChange: false,
        }
        // Test data transformation and axis configuration
    })
})

// GrapherState.test.ts  
describe("Backward Compatibility", () => {
    test("showYearLabels still works for scatter plots", () => {
        const grapher = new GrapherState({
            showYearLabels: true,
            chartTypes: [GRAPHER_CHART_TYPES.ScatterPlot],
        })
        expect(grapher.isRelativeMode).toBe(true)
    })
})
```

### Integration Testing (1 day)
- Admin interface updates
- Chart rendering with mixed modes  
- Export functionality
- URL parameter handling

### End-to-End Testing (1 day)
- Full user workflows
- Chart creation and editing
- Data visualization accuracy
- Performance benchmarking

## Performance Considerations

### Computational Overhead
- **Additional Conditionals**: Minimal impact (~1-2% in transform functions)
- **Memory Usage**: No significant increase (same data, different transformations)
- **Render Performance**: No expected impact on rendering speed

### Optimization Opportunities
```typescript
// Cache computed properties
@computed get axisTransformationConfig() {
    return {
        xAxisRelative: this.manager.xAxisAverageAnnualChange || this.legacyIsRelativeMode,
        yAxisRelative: this.manager.yAxisAverageAnnualChange || this.legacyIsRelativeMode,
    }
}
```

### Performance Monitoring
- Add performance markers for transformation steps
- Monitor chart render times before/after implementation
- Set up alerts for regression detection

## Rollback Strategy

### High Rollback Feasibility

The implementation is designed with rollback in mind:

#### 1. Feature Flags
```typescript
// In GrapherState
@computed get useIndependentAxisControls(): boolean {
    return !!window.OWID_FEATURES?.independentAxisControls
}
```

#### 2. Database Rollback
```sql
-- Quick disable without data loss
UPDATE charts SET 
    xAxisAverageAnnualChange = NULL,
    yAxisAverageAnnualChange = NULL
WHERE xAxisAverageAnnualChange IS NOT NULL 
   OR yAxisAverageAnnualChange IS NOT NULL;
```

#### 3. Code Rollback
- All changes are additive to existing functionality
- Legacy `showYearLabels` behavior preserved
- Feature can be disabled via feature flag without code changes

#### 4. Gradual Rollback
- Disable for new charts first
- Monitor for issues
- Revert existing charts if needed
- Full rollback as last resort

### Rollback Triggers
- Significant increase in error rates (>5% above baseline)
- Performance degradation (>10% increase in chart render time)
- User complaints about unexpected behavior
- Data accuracy issues

## Development Timeline

### Week 1-2: Core Infrastructure
- **Days 1-2**: Type system and schema updates
- **Days 3-5**: GrapherState changes and backward compatibility
- **Days 6-7**: Chart manager interface updates

### Week 2-3: Chart Implementation  
- **Days 8-11**: ScatterPlotChartState logic updates
- **Days 12-13**: Axis configuration and formatting
- **Days 14**: Integration testing

### Week 3: UI and Polish
- **Days 15-17**: Admin interface implementation
- **Days 18-19**: UI testing and refinement
- **Days 20**: Documentation and migration planning

### Optional Week 4: Testing and Deployment
- **Days 21-22**: Comprehensive testing
- **Days 23-24**: Performance optimization
- **Day 25**: Production deployment and monitoring

## Security Considerations

### Input Validation
- New boolean properties require same validation as existing properties
- Admin interface validation prevents invalid states
- URL parameter validation for any new query parameters

### Data Access
- No new data access patterns introduced
- Existing permission model applies to new properties
- No additional security audit required

### Cross-Site Scripting (XSS)
- No user-provided strings in new functionality
- Axis labels follow existing sanitization patterns
- No additional XSS vectors introduced

## Accessibility Considerations

### Screen Readers
- Axis labels remain descriptive with "Average annual change" prefixes
- Toggle controls use existing accessible patterns
- No new accessibility requirements

### Keyboard Navigation
- New toggles follow existing tab order
- Keyboard shortcuts continue to work
- No impact on existing accessibility features

### Visual Impairments
- Chart rendering follows existing color and contrast guidelines
- Axis formatting maintains readability standards
- No changes to existing visual accessibility features

## Documentation Requirements

### Technical Documentation
- Update API documentation for new properties
- Chart configuration guide updates
- Migration guide for existing charts

### User Documentation
- Update admin interface guide
- Add examples of new analytical capabilities
- Create best practices guide for mixed axis analysis

### Training Materials
- Video tutorials for new functionality
- Interactive examples demonstrating use cases
- FAQ addressing common questions

## Conclusion and Recommendations

### Implementation Feasibility: High
The proposed enhancement is technically feasible with manageable complexity. The existing architecture provides good foundation for independent axis control.

### Recommended Approach
1. **Incremental Implementation**: Build features incrementally with comprehensive testing at each stage
2. **Backward Compatibility First**: Ensure existing functionality remains intact throughout development
3. **Feature Flag Deployment**: Use feature flags for safe, gradual rollout
4. **Comprehensive Testing**: Prioritize testing edge cases and performance impacts

### Key Success Factors
1. **Thorough Testing**: Especially around data transformation edge cases
2. **Clear Documentation**: Help users understand and adopt new capabilities  
3. **Performance Monitoring**: Ensure no negative impact on chart rendering
4. **User Feedback Integration**: Gather feedback early and iterate

### Next Steps
1. **Stakeholder Review**: Review this analysis with team leads
2. **Architecture Approval**: Confirm technical approach aligns with system goals
3. **Sprint Planning**: Break down implementation into manageable sprints
4. **Development Environment Setup**: Prepare development and testing environments

This enhancement will significantly expand OWID's analytical capabilities by enabling powerful trajectory vs. outcome comparisons, making it a valuable addition to the platform's visualization toolkit.