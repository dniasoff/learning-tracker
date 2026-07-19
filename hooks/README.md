# Git Hooks

## Pre-commit Hook

The pre-commit hook runs `dart format` and `dart analyze` before each commit to ensure code quality.

### Installation

```bash
# From repository root
make install-hooks
```

### What it does

1. **Format check**: Ensures all Dart code is formatted according to `dart format`
2. **Static analysis**: Runs `dart analyze --fatal-infos` to catch potential issues

### Skip hook (not recommended)

If you need to skip the hook temporarily:

```bash
git commit --no-verify -m "Your message"
```

⚠️ **Warning**: CI will still run these checks, so it's better to fix issues locally.

### Troubleshooting

If the hook fails:

1. **Formatting issues**:
   ```bash
   cd learning_tracker
   dart format .
   ```

2. **Analysis issues**:
   ```bash
   cd learning_tracker
   dart analyze
   ```
   Fix reported issues and try committing again.
