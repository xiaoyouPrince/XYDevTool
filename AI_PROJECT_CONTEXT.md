# AI Project Context

> This file is the project-specific AI entry point for XYDevTool.  
> General AI collaboration rules live in `/Users/quxiaoyou/Documents/AI`.

## Must Read First

1. `/Users/quxiaoyou/Documents/AI/README.md`
2. `/Users/quxiaoyou/Documents/AI/AI协作问题复盘与实践指南.md`
3. `README.zh-CN.md`
4. `docs/logging-architecture-notes.md`
5. `.prd/network/README.md`
6. `.prd/network/history-grouping-v1.md`
7. `.prd/network/history-appkit-migration.md`
8. `.cursor/skills/xydevtool-network/SKILL.md` when touching the Network module

If these files conflict, prefer current source code and App Help documents over older AI reference files.

## Project Shape

XYDevTool is a macOS developer tool app. Main features include JSON formatting, JSON-to-model generation, AppIcon generation, network request debugging, custom local server, image inspector, help docs, and local log viewing.

The app is an Xcode/CocoaPods project. Use the workspace as the main entry:

```bash
XYDevTool/XYDevTool.xcworkspace
```

## Build And Verify

Use workspace builds, not only the xcodeproj, because the app depends on CocoaPods frameworks.

```bash
xcodebuild \
  -workspace XYDevTool/XYDevTool.xcworkspace \
  -scheme XYDevTool \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

If command-line Xcode tries to write under `~/Library/Developer/Xcode/DerivedData` and hits permission warnings, keep `-derivedDataPath build` or another explicit writable path.

## Project-Specific Rules

- Network history uses `HistoryNode.id` as the internal key for selection, deletion, dragging, and editor loading.
- Request `name` is the business key for same-name update behavior.
- The Network history tree is AppKit `NSOutlineView` embedded in SwiftUI. Do not restore the old SwiftUI flat `ForEach` history list.
- Do not treat `NetResquestController`, `Network.storyboard`, or old `View/LeftView.swift` / `View/TopView.swift` as the current Network UI path.
- For pre-request script behavior, prefer `XYDevTool/XYDevTool/Resource/Help/network-tool.md` and source code over stale references.
- Logging follows `Logger` + `LoggingSystem` + `LocalLogService`; do not reintroduce app-wide business enum coupling without a clear reason.

## Important Paths

| Area | Path |
| --- | --- |
| App entry | `XYDevTool/XYDevTool/AppDelegate.swift` |
| Main menu/windows | `XYDevTool/XYDevTool/ViewController.swift` |
| Logging core | `XYDevTool/XYDevTool/Core/Logging/` |
| Log viewer | `XYDevTool/XYDevTool/FEATURES/LogViewer/` |
| Network model | `XYDevTool/XYDevTool/FEATURES/Network/NetworkDataModel.swift` |
| Network tree model | `XYDevTool/XYDevTool/FEATURES/Network/NetModels.swift` |
| Network AppKit history tree | `XYDevTool/XYDevTool/FEATURES/Network/AppKitViews/` |
| Network SwiftUI panels | `XYDevTool/XYDevTool/FEATURES/Network/SwiftUIViews/` |
| App Help docs | `XYDevTool/XYDevTool/Resource/Help/` |
| Release script | `release.sh` |

## Documentation Maintenance

When a user-facing feature changes, update App Help docs under `Resource/Help/` and README if needed.

When Network architecture or history behavior changes, update `.prd/network/*` and `.cursor/skills/xydevtool-network/*`.

Keep general AI collaboration lessons in `/Users/quxiaoyou/Documents/AI`, not duplicated in this repository.
