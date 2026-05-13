# learning_tracker_lints

Custom lint rules for the Learning Tracker project. Powered by [custom_lint](https://pub.dev/packages/custom_lint).

---

## Rule 1 — `no_curriculum_display_name_bypass`

### What it checks

Fails on any direct property access of `.displayNameEn` or `.displayNameHe` outside the canonical whitelist:

- `lib/core/labels/` — the only place allowed to consume raw display-name fields
- Files ending in `.g.dart` or `.freezed.dart` — generated code (excluded automatically)

### Why it exists

Story 25.9 introduced `CurriculumLabelRenderer` as the **sole** consumer of curriculum display names. All presentation and business logic must go through this renderer so that:

- Label lookup is locale-aware and centralised.
- Regressions (e.g., hardcoded language selection) are caught automatically by CI.

### How to fix

**Before (banned):**
```dart
Text(item.displayNameEn); // direct field access
```

**After (correct):**
```dart
// Inject or locate via Riverpod:
final label = ref.watch(curriculumLabelRendererProvider);
Text(label.render(item));
```

---

## Rule 2 — `no_feature_cross_import`

### What it checks

Fails on any `import 'package:learning_tracker/features/X/…'` that appears inside a file under `features/Y/` (a different feature), **unless** the imported path is exactly `providers.dart` (or ends with `/providers.dart`).

### Why it exists

Following NFR2 / NFR17, features must be independently deployable and testable. Direct deep imports between features create hidden coupling that:

- Breaks feature isolation and makes incremental builds unreliable.
- Makes it impossible to reason about a feature's public API surface.

The single allowed crossing point is `features/<feature>/providers.dart`, which is the deliberate, documented public surface.

### How to fix

**Before (banned):**
```dart
// Inside features/dashboard/...
import 'package:learning_tracker/features/learning/data/repositories/progress_repository.dart';
```

**After (correct):**
```dart
// Use the public providers surface:
import 'package:learning_tracker/features/learning/providers.dart';
// Then read the provider from Riverpod rather than importing the repo directly.
```

If the type you need is not yet exposed through `providers.dart`, add it to that file rather than bypassing the boundary.

---

---

## Rule 3 — `no_firebase_outside_core`

### What it checks

Fails on any import of a Firebase SDK package in a file that is **not** under one of these authorised directories:

- `lib/core/auth/` — the authentication domain (Firebase Auth)
- `lib/core/sync/` — the Firestore / Firebase Storage sync domain

Restricted package prefixes:

- `package:firebase_auth/`
- `package:cloud_firestore/`
- `package:firebase_storage/`

Generated files (`.g.dart`, `.freezed.dart`) are excluded automatically.

### Why it exists

NFR3 requires that all Firebase interaction be confined to the core infrastructure layer. This prevents Firebase types from leaking into feature and presentation code, making the Firebase dependency replaceable and testable in isolation.

### How to fix

**Before (banned):**
```dart
// Inside lib/features/dashboard/...
import 'package:cloud_firestore/cloud_firestore.dart';

final db = FirebaseFirestore.instance;
```

**After (correct):**
```dart
// Inject the abstraction from lib/core/sync/:
import 'package:learning_tracker/core/sync/sync_repository.dart';

// Use the injected SyncRepository; never touch Firestore directly.
```

If the functionality you need is not yet exposed by `core/auth/` or `core/sync/`, extend those layers rather than bypassing the boundary.

---

## Rule 4 — `no_raw_talker`

### What it checks

Fails on the import:

```dart
import 'package:talker/talker.dart';
```

in any file that is **not** under `lib/core/logging/`.

Generated files (`.g.dart`, `.freezed.dart`) are excluded automatically.

Note: other Talker packages (e.g. `package:talker_flutter/…`) are **not** restricted by this rule; only the raw `package:talker/talker.dart` URI is banned.

### Why it exists

NFR8 requires that all log output pass through the centralised redaction layer before being written. Importing the raw `Talker` class bypasses redaction rules and log-level configuration, which can leak PII or make log noise uncontrollable.

### How to fix

**Before (banned):**
```dart
// Inside lib/features/auth/...
import 'package:talker/talker.dart';

final talker = Talker();
talker.log('User signed in: $email'); // leaks PII, bypasses redaction
```

**After (correct):**
```dart
// Use the application logger from the core logging abstraction:
import 'package:learning_tracker/core/logging/app_logger.dart';

AppLogger.instance.info('User signed in'); // redacted, centralised
```

---

## Rule 5 — `no_hardcoded_text_direction`

### What it checks

Warns on the following hardcoded directional values in Dart files:

| Banned expression | RTL-safe alternative |
|---|---|
| `EdgeInsets.only(left: …)` | `EdgeInsetsDirectional.only(start: …)` |
| `EdgeInsets.only(right: …)` | `EdgeInsetsDirectional.only(end: …)` |
| `Alignment.centerLeft` | `AlignmentDirectional.centerStart` |
| `Alignment.centerRight` | `AlignmentDirectional.centerEnd` |
| `TextAlign.left` | `TextAlign.start` |
| `TextAlign.right` | `TextAlign.end` |

**Severity: WARNING** — existing code has many legacy violations. New code must not introduce new ones. Clean up incrementally.

Generated files (`.g.dart`, `.freezed.dart`) are excluded automatically.

### Why it exists

UX-DR5 and NFR16 mandate full RTL support (Hebrew UI). Hardcoded `left`/`right` variants assume LTR layout and produce mirror-image bugs when the device locale switches to Hebrew or any other RTL language.

### How to fix

**Before (banned):**
```dart
Padding(
  padding: EdgeInsets.only(left: 16),
  child: Text(
    label,
    textAlign: TextAlign.left,
  ),
);
```

**After (correct):**
```dart
Padding(
  padding: EdgeInsetsDirectional.only(start: 16),
  child: Text(
    label,
    textAlign: TextAlign.start,
  ),
);
```

---

## Configuration

All rules are enabled automatically. To disable one (discouraged):

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - no_curriculum_display_name_bypass: false   # discouraged
    - no_feature_cross_import: false             # discouraged
    - no_firebase_outside_core: false            # discouraged
    - no_raw_talker: false                       # discouraged
    - no_hardcoded_text_direction: false         # discouraged
```
