# Enhancing `ZigZag.mq5`

The current implementation provides a comprehensive MetaTrader 5 ZigZag indicator, but a few focused refactors can make it easier to maintain, test, and extend.

## 1. Reduce Global State
- Group related globals into structs (e.g., indicator buffers, ratio metrics) and pass them explicitly to the functions that need them.
- Replace `static` state such as `isBusy` with a class/struct member so the indicator is re-entrant when compiled into an object-oriented EA.
- Encapsulate global constants (e.g., `NUM_LVLs`, `bar_limit`) as `input` parameters or `#define` directives to improve discoverability.

## 2. Factor Common Logic
- The `initial_run` and `bau_run` routines are nearly identical. Extract shared code into helpers that accept the mutable buffers as arguments and reuse them for both initial and incremental runs.
- Convert repetitive `if(direction > 0)` blocks to helper functions (`HandleBullishMove`, `HandleBearishMove`) to make the flow easier to follow and test.

## 3. Improve Buffer Handling
- Replace magic numbers (`zzH[last] <= _Point`) with descriptive functions such as `IsBufferEmpty(value)`.
- Guard assignments with array bounds checks and consider using `ArrayInitialize` with `EMPTY_VALUE` to make empty slots explicit.

## 4. Simplify Timeframe Math
- Cache the result of `PeriodSeconds` at initialization and recompute only when `_Period` changes.
- Move the repetitive `if(Hxbars < rates_total)` checks into a helper (`DrawGuideLine(int horizon, string label)`), reducing boilerplate.

## 5. Strengthen Diagnostics
- Replace `Print`/`Comment` walls of text with formatted logging helpers that only run when `display` is `true`.
- Add guards in `DisplayComment` to skip heavy UI updates on every tick; throttle updates to one per minute.

## 6. Modernize Object Management
- Use `ObjectCreate` return values to validate that graphics were drawn successfully and handle errors gracefully.
- Wrap object creation into helper classes that automatically delete or update objects, preventing orphaned lines/labels on chart close.

## 7. Adopt Consistent Naming & Style
- Rename variables like `den2`, `den4` to `twoHourSampleCount`, etc., for clarity.
- Consolidate repeated `ArraySetAsSeries` calls; they can be invoked once for each buffer during initialization.
- Apply consistent brace placement and indentation to improve readability and diffability.

## 8. Document Domain Decisions
- Add inline comments describing the rationale behind ratios (`DN_Ratio`, `DD_Ratio`), expected ranges, and how they are used downstream.
- Include a top-level README section that explains how the indicator’s multiple plots (`zzC`, `zzA`) differ and when to enable `display`.

These changes keep the indicator’s trading logic intact while making it significantly easier for future contributors to reason about and extend.
