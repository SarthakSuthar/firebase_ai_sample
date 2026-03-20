---
trigger: always_on
---

---
name: "flutter-performance"
description: "Optimize the performance of your Flutter app"
---

# Flutter Performance Optimization

##Goal
Analyzes and optimizes Flutter application performance by identifying jank, excessive rebuilds, and expensive rendering operations. Implements best practices for UI rendering, state management, and layout constraints. Utilizes Flutter DevTools, Chrome DevTools (for web), and integration tests to generate actionable performance metrics, ensuring frames render within the strict 16ms budget.

## Decision Logic
Evaluate the target application using the following decision tree to determine the optimization path:

1. **Is the goal to establish a performance baseline?**
   * **Yes:** Implement an integration test using `traceAction` and `TimelineSummary`.
   * **No:** Proceed to step 2.
2. **Is the application running on Web?**
   * **Yes:** Enable `debugProfileBuildsEnabled` and use Chrome DevTools Performance panel.
   * **No:** Run the app on a physical device in `--profile` mode and launch Flutter DevTools.
3. **Which thread is showing jank (red bars > 16ms) in the DevTools Performance View?**
   * **UI Thread:** Optimize `build()` methods, localize `setState()`, use `const` constructors, and replace string concatenation with `StringBuffer`.
   * **Raster (GPU) Thread:** Minimize `saveLayer()`, `Opacity`, `Clip`, and `ImageFilter` usage. Pre-cache complex images using `RepaintBoundary`.
   * **Both:** Start by optimizing the UI thread (Dart VM), as expensive Dart code often cascades into expensive rendering.

## Instructions
1.**Optimize UI Thread (Build Costs)**
   If the UI thread exceeds 8ms per frame, refactor the widget tree:
   *   **Localize State:** Move `setState` calls as low in the widget tree as possible.
   *   **Use `const`:** Apply `const` constructors to short-circuit rebuild traversals.
   *   **String Building:** Replace `+` operators in loops with `StringBuffer`.

   ```dart
   // BAD: Rebuilds entire widget tree
   setState(() { _counter++; });

   // GOOD: Encapsulated state
   class CounterWidget extends StatefulWidget { ... }
   // Inside CounterWidget:
   setState(() { _counter++; });
   ```

   ```dart
   // GOOD: Efficient string building
   final buffer = StringBuffer();
   for (int i = 0; i < 1000; i++) {
     buffer.write('Item $i');
   }
   final result = buffer.toString();
   ```

2.**Optimize Raster Thread (Rendering Costs)**
   If the Raster thread exceeds 8ms per frame, eliminate expensive painting operations:
   *   Replace `Opacity` widgets with semitransparent colors where possible.
   *   Replace `Opacity` in animations with `AnimatedOpacity` or `FadeInImage`.
   *   Avoid `Clip.antiAliasWithSaveLayer`. Use `borderRadius` properties on containers instead of explicit clipping widgets.

   ```dart
   // BAD: Expensive Opacity widget
   Opacity(
     opacity: 0.5,
     child: Container(color: Colors.red),
   )

   // GOOD: Semitransparent color
   Container(color: Colors.red.withValues(alpha: 0.5))
   ```

3.**Fix Layout and Intrinsic Passes**
   Identify and remove excessive layout passes caused by intrinsic operations (e.g., asking all children for their size before laying them out).
   *   Use lazy builders (`ListView.builder`, `GridView.builder`) for long lists.
   *   Avoid `ShrinkWrap: true` on scrollables unless absolutely necessary.

## Constraints
*   **NEVER** profile performance in Debug mode. Always use `--profile` mode on a physical device.
*   **NEVER** override `operator ==` on `Widget` objects. It results in O(N²) behavior and degrades performance. Rely on `const` caching instead.
*   **NEVER** put a subtree in an `AnimatedBuilder` that does not depend on the animation. Build the static part once and pass it as the `child` parameter.
*   **DO NOT** use constructors with a concrete `List` of children (e.g., `Column`, `ListView`) if most children are off-screen. Always use `.builder` constructors for lazy loading.
*   **DO NOT** use `saveLayer()` unless absolutely necessary (e.g., dynamic overlapping shapes with transparency). Precalculate and cache static overlapping shapes.

