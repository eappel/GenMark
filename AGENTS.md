# Working in This Codebase

## Core Development Philosophy

### Primary Approach: Make It Work, Make It Right, Make It Fast

Follow Kent Beck's principle in this exact order:

#### 1. Make It Work
- Focus on getting the feature functioning correctly
- Don't worry about perfect code structure initially
- Ensure all tests pass for the feature
- Prioritize behavior over aesthetics
- Apply YAGNI: Don't add functionality you don't need yet

#### 2. Make It Right
- Refactor once the feature works
- Clean up code structure and readability
- Apply the Rule of Three for duplication
- Improve naming and organization
- Tests provide safety net for refactoring

#### 3. Make It Fast
- Optimize performance only after code is working and clean
- Use profilers to identify actual bottlenecks
- Don't optimize prematurely
- Maintain test coverage during optimization
- **Measure before and after**: Performance improvements must be quantifiable

### Guiding Principles

#### YAGNI (You Aren't Gonna Need It)
- Only implement features when actually needed, not when anticipated
- Avoid speculative generality and overengineering
- Keep solutions simple until complexity is proven necessary
- Trust that you can add features later when requirements are clear

#### Rule of Three
- First time: Just write the code
- Second time: Notice the duplication but proceed
- Third time: Refactor to eliminate duplication
- Balance between premature abstraction and code duplication
- Wait for patterns to emerge before creating abstractions

#### DRY (Don't Repeat Yourself) - Applied Pragmatically
- Each piece of knowledge should have a single, authoritative representation
- BUT: Apply after the Rule of Three triggers
- Focus on eliminating duplication of business logic, not all code similarity
- Prefer duplication over wrong abstraction (AHA principle)

### Practical Balance

When these principles conflict:
1. **Start with YAGNI**: Don't build what you don't need
2. **Allow some duplication initially**: Follow Rule of Three
3. **Refactor when patterns emerge**: Apply DRY thoughtfully
4. **Keep it working**: Test coverage enables confident refactoring

Example workflow:
- Write simple, working code first (YAGNI + Make It Work)
- Allow duplication up to 2 instances (Rule of Three)
- On 3rd instance, consider refactoring (DRY + Make It Right)
- Profile before optimizing (Make It Fast)

## Daily Workflow
- Reference the Makefile for operations

## Quick Reference
- `make open`: generate + open workspace
- `make reload`: regenerate without opening
- `make clean`: reinstall Tuist deps + regenerate
- `make build`: build `GenMark` (framework) for iOS Simulator
- `make build-example`: build `GenMarkExample` app for iOS Simulator

## Code Style Guidelines
- Comments should only explain the "why" for non-intuitive code, not the "what"
- Avoid comments that merely describe what the code does
- Use `TODO(ai)` for future todo items that need attention

## Performance Optimization Protocol

### Requirements for Performance Work

**All performance improvements must be measurable and verified.**

1. **Before optimization**
   - Write performance tests that measure current baseline
   - Measure specific metrics: execution time, memory usage, CPU cycles, etc.
   - Document the baseline measurements in test comments
   - Use profilers to identify actual bottlenecks, not assumed ones

2. **Create measurement tests**
   ```swift
   // Example: Test must measure and assert on performance
   func testRenderingPerformance() {
       let baseline = 0.5 // seconds
       measure {
           // Code to measure
       }
       XCTAssertLessThan(executionTime, baseline)
   }
   ```

3. **During optimization**
   - Keep performance tests running to track progress
   - Try multiple approaches and measure each
   - Document why specific optimizations were chosen
   - Ensure functional tests still pass

4. **After optimization**
   - Performance tests must show measurable improvement
   - Document the performance gains in commit messages
   - Include before/after metrics in code comments
   - Consider trade-offs (complexity vs performance gain)

### Unacceptable Performance Work
- ❌ "It feels faster" without measurements
- ❌ Optimizing without baseline metrics
- ❌ Complex optimizations for negligible gains
- ❌ Breaking functionality for performance
- ❌ Optimizing before profiling

### Required Performance Deliverables
- ✅ Baseline performance test before changes
- ✅ Profiler data showing bottlenecks
- ✅ Updated performance test showing improvement
- ✅ Documented metrics (e.g., "Reduced from 500ms to 50ms")
- ✅ All existing tests still passing

## Problem-Solving Protocol

### When Stuck or Facing Errors
**NEVER remove functionality to "fix" a problem.** Instead:

1. **Debug systematically**
   - Read error messages carefully
   - Check logs and stack traces
   - Use print debugging if needed
   - Verify assumptions about the code

2. **Ask clarifying questions**
   - Request more context about requirements
   - Ask about expected behavior
   - Clarify business logic constraints
   - Seek examples of similar working code

3. **Explore alternative approaches**
   - Try different implementation strategies
   - Research documentation and examples
   - Consider edge cases and error conditions
   - Look for existing patterns in the codebase

4. **Preserve existing functionality**
   - Comment out problematic code temporarily, don't delete
   - Use feature flags if needed
   - Maintain backward compatibility
   - Keep tests passing for unrelated features

### Unacceptable "Solutions"
- ❌ Removing features because they're hard to fix
- ❌ Simplifying requirements without permission
- ❌ Skipping error handling
- ❌ Ignoring test failures
- ❌ Deleting code you don't understand

### Acceptable Approaches
- ✅ Asking for help or clarification
- ✅ Proposing multiple solution options
- ✅ Implementing partial solutions with clear TODOs
- ✅ Adding diagnostic code to understand issues
- ✅ Researching and learning before implementing

## Build & Test Gate (Run After Every Change)
- Run unit tests: `make test` to ensure the codebase builds and tests pass.
- If Tuist reports caching/manifest issues: `tuist clean && tuist fetch`, then rerun the above.
