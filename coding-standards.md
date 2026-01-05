# Coding Standards - Shtetl Zmanim

**Status:** CAST-IRON RULES - Violations block PRs
**Audience:** AI agents and developers

---

## CRITICAL VIOLATIONS (PR Blockers)

### 1. Publisher Zmanim - MUST Link
Every publisher zman MUST have `master_registry_id` OR `linked_zman_id` - no orphans.

### 2. Service Restart - Use `./restart.sh`
FORBIDDEN: `go run`, `npm run dev`, `pkill` - always use `./restart.sh`

### 3. Hardcoded Colors
```tsx
// FORBIDDEN
className="text-[#1e3a5f]" | style={{ color: '#ff0000' }}

// REQUIRED - design tokens
className="text-primary" | className="bg-primary/90" | className="text-muted-foreground"
```

### 4. Raw fetch() in Components
```tsx
// FORBIDDEN
fetch(`${API_BASE}/api/v1/endpoint`)

// REQUIRED - unified API client
const api = useApi();
await api.get<DataType>('/publisher/profile');   // Auth + X-Publisher-Id
await api.public.get('/countries');               // No auth
await api.admin.get('/admin/stats');              // Auth only
```

### 5. React Query Pattern
```tsx
const { data, isLoading, error } = usePublisherQuery<ProfileData>('publisher-profile', '/publisher/profile');
const mutation = usePublisherMutation<Profile, UpdateRequest>('/publisher/profile', 'PUT', { invalidateKeys: ['publisher-profile'] });
```

### 6. Clerk Auth - MUST check isLoaded first
```tsx
const { isLoaded, isSignedIn, user } = useUser();
if (!isLoaded) return <LoadingSpinner />;
if (!isSignedIn) redirect('/sign-in');
```

### 7. Centralize Logic - NEVER Patch at Consumer

**NON-NEGOTIABLE:** All data transformations, formatting, and business logic MUST be applied at the **source/service layer**, not scattered across consumers.

**FORBIDDEN - Patching in view/consumer code:**
```tsx
// ❌ FORBIDDEN - Transforming data at the consumer
{events.map(event => (
  <span>{event === 'Shabbat' ? getShabbatLabel(style) : event}</span>
))}

// ❌ FORBIDDEN - Every consumer must "fix" the data
function formatZmanName(name: string, style: TransliterationStyle) {
  // This logic should be in the backend service!
}
```

**REQUIRED - Fix at the source:**
```go
// ✓ REQUIRED - Backend service returns correctly formatted data
func (s *ZmanimService) GetEvents(ctx context.Context, params EventParams) []Event {
    transliterationStyle := params.TransliterationStyle
    events := []Event{}

    if isShabbat(params.Date) {
        // Apply transliteration at the source
        eventName := calendar.GetTransliteratedName("Shabbat", transliterationStyle)
        events = append(events, Event{Name: eventName})
    }
    return events
}
```

**Why:**
- **Consistency:** Every consumer gets correctly formatted data automatically
- **Maintainability:** One fix location, not N scattered patches
- **DRY:** Business logic lives in one place
- **Testability:** Test the service once, not every consumer
- **Scalability:** New consumers get correct behavior for free

**Detection:**
```bash
# Look for suspicious consumer-side transformations
grep -r "=== 'Shabbat'" web/  # String replacement in view
grep -r "format.*Name.*style" web/components/  # Formatting helpers that should be backend
```

**Exceptions:**
- Pure UI formatting (e.g., date display format for locale)
- Memoized computed values derived from already-correct data

---

### 8. Entity References - ALWAYS Use IDs
**FORBIDDEN:** Text-based lookups, name matching, or string identifiers in API calls/database queries.

**REQUIRED:** Numeric IDs for ALL entity references.

```tsx
// FORBIDDEN - text matching
await api.post('/coverage', { city_name: 'Jerusalem', country: 'Israel' });
const city = await db.GetCityByName(ctx, "New York");

// REQUIRED - ID-based references
await api.post('/coverage', { city_id: 293397 });
const city = await db.GetCityByID(ctx, cityID);
```

**Why:** Text matching causes:
- Case sensitivity bugs ("jerusalem" ≠ "Jerusalem")
- Locale issues ("München" vs "Munich")
- Ambiguity (multiple cities with same name)
- Fragile integrations (names change, IDs don't)
- Performance problems (string comparison vs indexed ID lookup)

**Frontend Rules:**
- Select components MUST store and send numeric IDs, not labels
- Quick-select buttons MUST lookup and store database IDs on mount
- Coverage/city selectors MUST use `city_id`, never `city_name`

**Backend Rules:**
- Endpoints MUST accept ID parameters, not text lookups
- Database queries MUST use `WHERE id = $1`, not `WHERE name = $1`
- Foreign keys MUST reference numeric IDs
- No `GetEntityByName` queries except for initial seed/admin operations

**Exceptions:**
- User-facing search endpoints (e.g., `/cities?search=jerusalem`)
- Admin tools for data exploration
- Initial data seeding scripts

---

## Security - Secrets Management - ZERO TOLERANCE

**FORBIDDEN - NEVER commit to repository:**
- Passwords, API keys, tokens, secrets
- Database connection strings (with credentials)
- Private keys, certificates
- AWS credentials, S3 bucket URLs with keys
- OAuth client secrets
- Session secrets, JWT signing keys
- `.env` files with real credentials

**REQUIRED patterns:**

```bash
# ✓ CORRECT - Use environment variables
Database credentials are always in api/.env
DATABASE_URL=postgresql://...         # In .env (gitignored)
AWS_S3_BUCKET=my-bucket               # In .env (gitignored)
CLERK_SECRET_KEY=sk_test_...          # In .env (gitignored)

# ✓ CORRECT - Reference in code
dbURL := os.Getenv("DATABASE_URL")
apiKey := process.env.CLERK_SECRET_KEY
```

```go
// ✗ FORBIDDEN - Hardcoded credentials
const connStr = "postgresql://user:password@localhost/db"
const apiKey = "sk_live_abc123..."

// ✓ REQUIRED - Environment variables
connStr := os.Getenv("DATABASE_URL")
apiKey := os.Getenv("API_KEY")
```

```typescript
// ✗ FORBIDDEN - Hardcoded secrets
const apiKey = "sk_test_abc123...";
const dbUrl = "postgresql://user:pass@host/db";

// ✓ REQUIRED - Environment variables
const apiKey = process.env.CLERK_SECRET_KEY;
const dbUrl = process.env.DATABASE_URL;
```

**Configuration files:**
- `.env` → MUST be in `.gitignore`
- `.env.example` → Template with dummy values (safe to commit)
- `.env.local`, `.env.production` → MUST be in `.gitignore`

**Documentation:**
```bash
# .env.example (safe to commit)
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
CLERK_SECRET_KEY=sk_test_your_key_here
AWS_S3_BUCKET=your-bucket-name
```

**Exceptions (extremely rare):**
- Public API endpoints (but never with keys/tokens)
- Well-known public constants (e.g., `EARTH_RADIUS_KM = 6371`)
- Test fixtures with obviously fake data (`test@example.com`, `password123`)

**Detection:**
```bash
# Check for common violations before commit
./scripts/check-compliance.sh
grep -r "postgresql://.*:.*@" --include="*.go" --include="*.ts"
grep -r "sk_live_\|sk_prod_" --include="*.go" --include="*.ts"
```

**If accidentally committed:**
1. Immediately rotate/revoke the exposed secret
2. Remove from git history: `git filter-branch` or BFG Repo-Cleaner
3. Force push (coordinate with team)
4. Update all environments with new secrets

---

## Clean Code Policy - ZERO TOLERANCE

**FORBIDDEN patterns - delete, don't mark:**
- `@deprecated` annotations, `// Legacy`, `// TODO: remove`, `// FIXME`
- Fallback logic for old formats
- Dual-format support (`status == 'verified' || status == 'active'`)
- Re-exports "for compatibility"

**Rule:** One format only. Migrate data, update code, delete old code.

---

## Frontend Standards

### Component Pattern
```tsx
'use client';
import { useState, useEffect } from 'react';
import { useUser } from '@clerk/nextjs';
import { useApi } from '@/lib/api-client';

export function Component() {
  // 1. Hooks
  const { user, isLoaded } = useUser();
  const api = useApi();
  const [data, setData] = useState(null);

  // 2. Effects
  useEffect(() => { if (isLoaded) fetchData(); }, [isLoaded]);

  // 3. Early returns: Loading → Error → Content
  if (!isLoaded) return <Loader2 className="animate-spin" />;
  if (error) return <div className="text-destructive">{error}</div>;
  return <div>{/* content */}</div>;
}
```

### Design Tokens (MANDATORY)
| Token | Usage |
|-------|-------|
| `foreground/background` | Primary text/page bg |
| `card/card-foreground` | Card bg/text |
| `primary/primary-foreground` | CTAs, links/text on primary |
| `muted/muted-foreground` | Disabled bg/secondary text |
| `destructive` | Errors, delete |
| `border/input/ring` | Borders/form inputs/focus |

**Exceptions (require dark: variant):** Status colors (`text-green-600 dark:text-green-400`)

### Time Formatting - 12-hour ONLY
```tsx
import { formatTime, formatTimeShort } from '@/lib/utils';
formatTime('14:30:36')      // "2:30:36 PM"
formatTimeShort('14:30:36') // "2:30 PM"
```

### UI Component Selection (MANDATORY)

**CRITICAL:** Use consistent UI components across the application. Never mix native HTML elements with shadcn components.

#### Dropdown/Select Components

| Use Case | Required Component | Import Path |
|----------|-------------------|-------------|
| Single-value selection | `<Select>` | `@/components/ui/select` |
| Actions menu (sign out, settings) | `<DropdownMenu>` | `@/components/ui/dropdown-menu` |
| Searchable selection | `<Popover>` + `<Command>` | `@/components/ui/popover` + `@/components/ui/command` |
| Date picking | `<DatePickerDropdown>` | `@/components/zmanim/DatePickerDropdown` |
| Multi-select with categories | `<TagSelector>` | `@/components/shared/tags/TagSelector` |
| Geographic search | `<LocalityPicker>` | `@/components/shared/LocalityPicker` |

```tsx
// FORBIDDEN - Native HTML select
<select value={x} onChange={(e) => setValue(e.target.value)}>
  <option value="a">Option A</option>
  <option value="b">Option B</option>
</select>

// REQUIRED - shadcn Select
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

<Select value={x} onValueChange={setValue}>
  <SelectTrigger>
    <SelectValue placeholder="Select option" />
  </SelectTrigger>
  <SelectContent>
    <SelectItem value="a">Option A</SelectItem>
    <SelectItem value="b">Option B</SelectItem>
  </SelectContent>
</Select>
```

**Why consistent components matter:**
- Visual consistency across the application
- Accessibility (keyboard navigation, ARIA attributes)
- Theme support (dark mode, design tokens)
- Predictable behavior for users

**Decision Tree:**
1. Need searchable list? → `Popover` + `Command`
2. Need multi-select? → `TagSelector` or custom with `Command`
3. Need date selection? → `DatePickerDropdown`
4. Need geographic search? → `LocalityPicker`
5. Need action menu (buttons, not values)? → `DropdownMenu`
6. Simple single-value selection? → `Select`

---

## Backend Standards

**API Patterns Documentation:** See `/api/internal/docs/patterns/` for detailed pattern guides:
- [Security Patterns](../api/internal/docs/patterns/security-patterns.md) - **MANDATORY** - Authentication, authorization, IDOR prevention
- [Version History Pattern](../api/internal/docs/patterns/version-history.md) - Track changes with global or per-resource versioning
- [Soft Delete Pattern](../api/internal/docs/patterns/soft-delete.md) - Reversible deletion with audit trail
- [Patterns Index](../api/internal/docs/patterns/README.md) - Complete pattern catalog

### Handler Pattern (6 Steps)
```go
func (h *Handlers) HandlerName(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    // 1. Resolve publisher context
    pc := h.publisherResolver.MustResolve(w, r)
    if pc == nil { return }

    // 2. Extract URL params
    id := chi.URLParam(r, "id")

    // 3. Parse body
    var req struct { Name string `json:"name"` }
    json.NewDecoder(r.Body).Decode(&req)

    // 4. Validate
    if req.Name == "" { RespondValidationError(w, r, "msg", details); return }

    // 5. SQLc query (NO RAW SQL)
    result, err := h.db.Queries.GetSomething(ctx, sqlcgen.Params{...})

    // 6. Respond
    RespondJSON(w, r, http.StatusOK, result)
}
```

### PublisherResolver (REQUIRED)

**SECURITY CRITICAL:** Always use PublisherResolver to prevent tenant isolation attacks.

```go
// ❌ FORBIDDEN - manual extraction (CRITICAL SECURITY VULNERABILITY)
publisherID := r.Header.Get("X-Publisher-Id")
// User can access ANY publisher by changing header!

// ✅ REQUIRED - Validated against JWT claims
pc := h.publisherResolver.MustResolve(w, r)
if pc == nil { return }  // Response already sent (401/404)
publisherID := pc.PublisherID  // Safe - validated against JWT

// See: api/internal/docs/patterns/security-patterns.md
```

### Logging - slog only
```go
slog.Error("operation failed", "error", err, "user_id", userID)
// FORBIDDEN: fmt.Println, log.Printf
```

### Response Format
```json
{ "data": <payload>, "meta": { "timestamp": "...", "request_id": "..." } }
```

**RULE:** Pass data directly to RespondJSON - NEVER double-wrap

---

## Database Standards

### Primary Key Pattern (MANDATORY)

**THIS PROJECT (Integer IDs - REQUIRED):**
```sql
-- REQUIRED - All tables use integer 'id'
CREATE TABLE public.example_table (
    id SERIAL PRIMARY KEY,  -- or BIGSERIAL for high-volume
    name text NOT NULL,
    status_id smallint NOT NULL,  -- FK to lookup table
    created_at timestamptz DEFAULT now()
);

-- Lookup tables use GENERATED ALWAYS AS IDENTITY
CREATE TABLE public.example_statuses (
    id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key varchar(20) NOT NULL UNIQUE,
    display_name_hebrew text NOT NULL,
    display_name_english text NOT NULL,
    created_at timestamptz DEFAULT now()
);
```

**FUTURE PROJECTS ONLY (UUID Pattern):**
```sql
-- NOT FOR THIS PROJECT - Reference only
-- For greenfield/new projects outside Shtetl Zmanim
CREATE TABLE future_concept (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    -- See: db/migrations/TEMPLATE_uuid_concept.sql
);
```

**When to use which:**
- **Integer IDs (SERIAL):** THIS PROJECT - all tables (existing + new)
- **UUID:** FUTURE PROJECTS ONLY - not for Shtetl Zmanim
- **Reference:** `docs/architecture/PHASE2_3_IMPLEMENTATION.md` (template exists for future use)

### Lookup Table Pattern (MANDATORY)
```sql
CREATE TABLE public.{name}_statuses|_types|_levels|_sources (
    id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key varchar(20) NOT NULL UNIQUE,           -- Programmatic ID
    display_name_hebrew text NOT NULL,
    display_name_english text NOT NULL,
    description text,
    created_at timestamptz DEFAULT now()
);
```

**21 Verified Tables:** `publisher_statuses`, `algorithm_statuses`, `request_statuses`, `publisher_roles`, `coverage_levels`, `jewish_event_types`, `fast_start_types`, `calculation_types`, `edge_types`, `primitive_categories`, `zman_source_types`, `ai_content_sources`, `geo_levels`, `data_types`, `explanation_sources`, `day_types`, `event_categories`, `geo_data_sources`, `tag_types`, `time_categories`, `ai_index_statuses`

### Foreign Key Rules
```sql
-- REQUIRED - Integer FKs only
ALTER TABLE example_table
    ADD CONSTRAINT example_status_fkey
    FOREIGN KEY (status_id) REFERENCES example_statuses(id);

-- FORBIDDEN - VARCHAR FKs
status varchar(20) NOT NULL  -- ✗ FORBIDDEN
status_id smallint NOT NULL  -- ✓ REQUIRED
```

**Exceptions (ONLY these 4):**
1. `languages.code` (ISO 639 standard)
2. Junction tables with composite PKs
3. Boundary tables (1:1 with parent, e.g., `geo_city_boundaries`)
4. `schema_migrations.version`

### Migration Pattern
```sql
-- 1. Create lookup table
CREATE TABLE example_types (
    id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key varchar(20) NOT NULL UNIQUE,
    display_name_hebrew text NOT NULL,
    display_name_english text NOT NULL
);

-- 2. Seed data (use key, not id)
INSERT INTO example_types (key, display_name_hebrew, display_name_english) VALUES
('type_a', 'סוג א', 'Type A'),
('type_b', 'סוג ב', 'Type B');

-- 3. Add FK column
ALTER TABLE example_table ADD COLUMN type_id smallint;

-- 4. Backfill
UPDATE example_table SET type_id = (SELECT id FROM example_types WHERE key = 'type_a');

-- 5. Add constraint
ALTER TABLE example_table ADD CONSTRAINT fk_type FOREIGN KEY (type_id) REFERENCES example_types(id);
```

### Soft Delete Pattern (MANDATORY)

**See full documentation:** `/api/internal/docs/patterns/soft-delete.md`

**Use soft delete when:**
- Records have audit trail requirements (who deleted, when)
- Data may need to be restored
- Records have dependencies that need to remain queryable for historical purposes
- Compliance/regulatory requirements mandate data retention
- User-generated content that should be recoverable

**Use hard delete when:**
- Temporary/cache data (sessions, rate limit counters)
- Test/fixture data
- Purely technical records with no business value
- GDPR/privacy "right to be forgotten" requests (after audit window)
- Cascade deletions where parent soft-delete handles it

**Required columns:**
```sql
CREATE TABLE example_table (
    id SERIAL PRIMARY KEY,
    -- ... other columns ...
    deleted_at timestamptz DEFAULT NULL,
    deleted_by text DEFAULT NULL,  -- Clerk user ID
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Index for soft-delete queries (critical for performance)
CREATE INDEX idx_example_table_active ON example_table(id) WHERE deleted_at IS NULL;
```

**Query patterns:**
```sql
-- REQUIRED - All SELECT queries MUST filter out soft-deleted records
SELECT * FROM example_table WHERE deleted_at IS NULL;

-- With other filters
SELECT * FROM example_table
WHERE deleted_at IS NULL
  AND status_id = $1
  AND created_at > $2;

-- Soft delete operation
UPDATE example_table
SET deleted_at = now(),
    deleted_by = $1
WHERE id = $2
  AND deleted_at IS NULL;  -- Prevent double-delete

-- Check if exists (active only)
SELECT EXISTS(
    SELECT 1 FROM example_table
    WHERE id = $1 AND deleted_at IS NULL
);

-- Count active records
SELECT COUNT(*) FROM example_table WHERE deleted_at IS NULL;
```

**Restore patterns:**
```sql
-- Restore soft-deleted record
UPDATE example_table
SET deleted_at = NULL,
    deleted_by = NULL
WHERE id = $1
  AND deleted_at IS NOT NULL;  -- Only restore if actually deleted

-- Restore with audit trail (RECOMMENDED)
-- Log to actions table first, then restore
UPDATE example_table
SET deleted_at = NULL,
    deleted_by = NULL,
    updated_at = now()
WHERE id = $1
  AND deleted_at IS NOT NULL;
```

**SQLc query examples:**
```sql
-- name: GetActivePublisher :one
SELECT * FROM publishers
WHERE id = $1 AND deleted_at IS NULL;

-- name: ListActivePublishers :many
SELECT * FROM publishers
WHERE deleted_at IS NULL
ORDER BY created_at DESC;

-- name: SoftDeletePublisher :exec
UPDATE publishers
SET deleted_at = now(),
    deleted_by = $1
WHERE id = $2
  AND deleted_at IS NULL;

-- name: RestorePublisher :exec
UPDATE publishers
SET deleted_at = NULL,
    deleted_by = NULL,
    updated_at = now()
WHERE id = $1
  AND deleted_at IS NOT NULL;
```

**Backend handler pattern:**
```go
func (h *Handlers) SoftDeleteEntity(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    pc := h.publisherResolver.MustResolve(w, r)
    if pc == nil { return }

    id, err := strconv.Atoi(chi.URLParam(r, "id"))
    if err != nil {
        RespondValidationError(w, r, "Invalid ID", nil)
        return
    }

    // Get Clerk user ID for audit
    userID := r.Context().Value("clerk_user_id").(string)

    err = h.db.Queries.SoftDeleteEntity(ctx, sqlcgen.SoftDeleteEntityParams{
        DeletedBy: sql.NullString{String: userID, Valid: true},
        ID: int32(id),
    })
    if err != nil {
        slog.Error("soft delete failed", "error", err, "id", id)
        RespondInternalError(w, r)
        return
    }

    RespondJSON(w, r, http.StatusOK, map[string]string{"status": "deleted"})
}
```

**CRITICAL: Index performance**
```sql
-- ALWAYS create partial index for active records
-- Without this, WHERE deleted_at IS NULL becomes full table scan
CREATE INDEX idx_{table}_active ON {table}(id) WHERE deleted_at IS NULL;

-- For filtered queries, add covering indexes
CREATE INDEX idx_publishers_active_status
ON publishers(status_id, created_at)
WHERE deleted_at IS NULL;
```

**Migration pattern:**
```sql
-- Add soft delete columns to existing table
ALTER TABLE example_table
    ADD COLUMN deleted_at timestamptz DEFAULT NULL,
    ADD COLUMN deleted_by text DEFAULT NULL;

-- Create index immediately (prevents performance degradation)
CREATE INDEX idx_example_table_active
ON example_table(id)
WHERE deleted_at IS NULL;

-- Update existing queries to filter out deleted records
-- (Handled in SQLc queries, not migration)
```

**FORBIDDEN patterns:**
```sql
-- ✗ FORBIDDEN - Missing deleted_at filter (returns deleted records!)
SELECT * FROM example_table WHERE id = $1;

-- ✗ FORBIDDEN - Using boolean is_deleted (wastes space, harder to query)
is_deleted boolean DEFAULT false

-- ✗ FORBIDDEN - Missing index (full table scan on every query)
-- (No WHERE deleted_at IS NULL index)

-- ✗ FORBIDDEN - Hard delete when soft delete is required
DELETE FROM example_table WHERE id = $1;  -- Audit trail lost!
```

**When working with soft-deleted records:**
- **Admin views:** May show deleted records with `deleted_at IS NOT NULL`
- **Audit queries:** Include deleted records for compliance reports
- **Cascade deletes:** Soft-delete children when parent is soft-deleted
- **Unique constraints:** Consider `WHERE deleted_at IS NULL` in unique indexes

**Example: Unique constraint with soft delete:**
```sql
-- Allow same slug if one is deleted
CREATE UNIQUE INDEX idx_publishers_slug_active
ON publishers(slug)
WHERE deleted_at IS NULL;
```

---

## Testing Standards

### Parallel Execution (REQUIRED)
```typescript
test.describe.configure({ mode: 'parallel' });  // Top of every spec
```

### Shared Fixtures (REQUIRED)
```typescript
// FORBIDDEN - per-test creation
test.beforeEach(async () => { testPublisher = await create(...); });

// REQUIRED - shared fixtures
import { getSharedPublisher } from '../utils';
const publisher = getSharedPublisher('verified-1');
```

**Shared Types:** `verified-1` to `verified-5`, `pending`, `suspended`, `with-algorithm-1/2`, `with-coverage`, `empty-1/2/3`

### Test Pattern
```typescript
import { test, expect } from '@playwright/test';
import { loginAsPublisher, getSharedPublisher, BASE_URL } from '../utils';

test.describe.configure({ mode: 'parallel' });

test('description', async ({ page }) => {
  const publisher = getSharedPublisher('verified-1');
  await loginAsPublisher(page, publisher.id);
  await page.goto(`${BASE_URL}/publisher/dashboard`);
  await page.waitForLoadState('networkidle');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

---

## Development Workflow

### Commands
```bash
./restart.sh              # ALWAYS - handles migrations, cleanup, tmux
./scripts/migrate.sh      # Run migrations
cd api && sqlc generate   # After schema changes
redis-cli -h redis FLUSHDB  # Clear cache
```

### Service URLs
| Service | Port |
|---------|------|
| Web | 3001 |
| API | 8080 |

### CI/Linting Fixes - ALWAYS Test Locally First

**FORBIDDEN:** Push-and-wait cycle (commit → push → wait for CI → repeat)

**REQUIRED:** Test ALL changes locally BEFORE committing

```bash
# E2E test fixes - verify against real database
psql $DATABASE_URL -c "SELECT p.id, p.name, ps.key as status FROM publishers p JOIN publisher_statuses ps ON p.status_id = ps.id WHERE p.slug LIKE 'e2e-%'"
cd web && npx tsc --noEmit  # Type check

# Linting fixes - run exact CI checks
cd api && golangci-lint run ./...
cd api && go build -v ./cmd/api ./internal/...
cd api && gofmt -l .  # Should return nothing

# Backend changes - build before push
cd api && go build -v ./cmd/api ./internal/...
cd api && go test ./...

# Frontend changes - type check before push
cd web && npm run type-check
cd web && npm run build

# After push - monitor workflows
gh run list --limit 5
gh run watch  # Watch latest run
```

**When to test what:**
- **E2E schema fixes** → Query local database, verify column names/types
- **Go linting errors** → Run `golangci-lint run`, fix locally, verify build
- **TypeScript errors** → Run `tsc --noEmit`, fix, verify build
- **Formatting** → Run `gofmt -w .` or `prettier --write .`
- **Any handler/service change** → Full build + test suite

**Monitoring after push:**
```bash
# Watch all 3 workflows complete
gh run watch

# If failures occur
gh run view --log-failed  # See error details
# Fix locally, test again, then push
```

**Why:** Local testing is 10x faster than push-and-wait. CI should be final validation, not iterative debugging.

---

## Concept Independence (ASPIRATIONAL)

**Source:** ["What You See Is What It Does" (arXiv:2508.14511v2)](https://arxiv.org/html/2508.14511v2#S3)

**⚠️ Status: Partial Compliance (Score: 6.5/10)**

### Implementation Status

**✅ COMPLETED (Phase 1-3):**
- Service layer extraction (`ZmanimLinkingService`)
- Query decomposition (`GetPublisherZmanim` split)
- Action reification table with causal tracking
- Request ID middleware for distributed tracing
- Geo abstraction layer (UUID-based `geo_location_references`)
- UUID template for future projects

**📋 REMAINING:**
- Extract more services for multi-concept operations
- Split complex queries (8+ concepts → 3-5 per query)
- Apply UUID pattern to new concepts (future projects only)

### Key Principles

**Provenance Tracking:** ✅ Implemented
- `actions` table records all state changes
- Request ID links HTTP requests to database actions
- Causal chain tracking via `parent_action_id`
- Service integration: `ZmanimLinkingService` records/completes actions

**Synchronization Boundaries:** 🟡 Partial
- ✅ Multi-concept ops SHOULD use services (e.g., `ZmanimLinkingService`)
- ⚠️ Some handlers still orchestrate directly

**Read/Write Separation:** ✅ Good
- Reads: SQLc queries
- Writes: SQLc (single concept) or services (multi-concept)

**Cross-Concept JOINs:** ⚠️ Complex
- Some queries JOIN 8+ concepts (see audit)
- Split complex queries into focused queries

**Naming Consistency:** ✅ Good
- Fully qualified paths: `/publisher/{id}/zmanim/{zman_id}`
- Concept → action → argument mapping

### Documentation
- **Audit:** `docs/compliance/concept-independence-audit.md`
- **Phase 1:** `docs/architecture/PHASE1_IMPLEMENTATION.md` (service extraction)
- **Phase 2+3:** `docs/architecture/PHASE2_3_IMPLEMENTATION.md` (action reification, UUID template)

---

## AI Agent Optimization

### Quick Reference
- 📚 **Start Here:** `docs/AI_QUICK_START.md`
- 📊 **Metrics:** `docs/compliance/status.yaml`
- 📖 **Rationale:** `docs/adr/` (5 ADRs)
- 🗺️ **Navigation:** `api/internal/handlers/INDEX.md`, `api/internal/db/queries/INDEX.md`, `web/components/INDEX.md`
- 🛠️ **Scripts:** `./scripts/check-compliance.sh`, `./scripts/ai-context.sh`

### File Headers (RECOMMENDED)
```tsx
/**
 * @file ComponentName.tsx
 * @pattern client-component
 * @compliance useApi:✓ design-tokens:✓
 */
```

```go
// File: handler.go
// Pattern: 6-step-handler
// Compliance: PublisherResolver:✓ SQLc:✓ slog:✓
```

### Architecture Docs
- **ADRs:** `001-sqlc`, `002-use-api`, `003-publisher-resolver`, `004-lookup-normalization`, `005-design-tokens`
- **Flows:** `docs/architecture/data-flow-diagrams.md`
- **Dependencies:** `docs/architecture/dependency-map.md`
- **Templates:** `docs/patterns/TEMPLATES.md`

### Pre-commit Hooks
```bash
./scripts/setup-hooks.sh  # One-time setup
# Checks: No raw SQL, no fmt.Printf, no raw fetch(), no hardcoded colors
```

---

## Quick Reference Checklists

### Frontend
1. `'use client'` only for hooks/events
2. `useApi()` for all API calls
3. Design tokens for colors
4. 12-hour time format
5. Check `isLoaded` before Clerk access

### Backend
1. PublisherResolver for publisher endpoints
2. SQLc for all queries (NO raw SQL)
3. slog for logging
4. Response helpers for all responses
5. Generic messages for 500s

### Testing
1. `test.describe.configure({ mode: 'parallel' })`
2. Shared fixtures only
3. `waitForLoadState('networkidle')` before assertions
4. Role/text selectors

### Database Schema
1. All tables use integer `id` (SERIAL/BIGSERIAL)
2. All lookup tables follow id + key pattern
3. All FKs reference integer `id` (except `languages.code`)
4. Zero VARCHAR/TEXT lookups
5. Seed data uses `key` column

---

## Technical Debt (2025-12-07)

| Category | Count | Severity |
|----------|-------|----------|
| Raw `fetch()` in .tsx | 73 | CRITICAL |
| `log.Printf/fmt.Printf` in Go | ~100 | HIGH |
| `waitForTimeout` in tests | 52 | HIGH |
| Double-wrapped API responses | 80+ | MEDIUM |

### Detection
```bash
grep -r "await fetch\(" web/app web/components --include="*.tsx" | wc -l
grep -rE "log\.Printf|fmt\.Printf" api/internal --include="*.go" | wc -l
```

---

## Git Standards

**Branches:** `feature/epic-{n}-{desc}` | `fix/{desc}` | `refactor/{scope}-{desc}`

**Commits:**
```
<type>(<scope>): <description>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```
Types: feat, fix, refactor, docs, test, chore

---

## PR Checklist

### Security (MANDATORY)
- [ ] **No secrets committed:** No passwords, API keys, tokens, credentials in code
- [ ] **Authentication:** Route uses appropriate middleware (RequireAuth/RequireRole/OptionalAuth)
- [ ] **Tenant isolation:** Uses PublisherResolver, NOT raw X-Publisher-Id header
- [ ] **IDOR prevention:** Queries filter by publisher_id/user_id
- [ ] **SQL injection:** ONLY SQLc queries (no raw SQL, no fmt.Sprintf)
- [ ] **Error handling:** Generic 500 messages, no stack traces/DB errors exposed
- [ ] **Input validation:** All inputs validated (body, URL params, query params)
- [ ] **See:** `api/internal/docs/patterns/security-patterns.md` for full checklist

### Code Quality
- [ ] Publisher zmanim linked (master_registry or linked_zman)
- [ ] Service restarts via `./restart.sh`
- [ ] No hardcoded colors
- [ ] No raw fetch()
- [ ] PublisherResolver pattern
- [ ] SQLc queries (no raw SQL)
- [ ] slog logging
- [ ] 12-hour time format
- [ ] E2E tests with parallel mode
- [ ] Database normalization:
  - [ ] New tables use integer `id` primary key
  - [ ] Lookup tables follow id + key pattern
  - [ ] FKs reference integer `id`
  - [ ] Zero VARCHAR lookups
  - [ ] Seed data uses `key`
