// Sefaria calendar fetcher — Go port of tool/fetch_sefaria_calendar_full.dart
// with stronger error handling.
//
// Fetches Sefaria's /api/calendars day-by-day and captures BOTH the English
// `ref` and Hebrew `displayValue.he` for every supported program. Writes
// atomically to tool/data/sefaria_calendar_cache.json so a crash mid-run
// can never corrupt the cache.
//
// Cache shape (matches the Dart fetcher byte-for-byte modulo trailing newline):
//   { "YYYY-MM-DD": { "<programKey>": { "en": "<ref>", "he": "<heRef>" } } }
//
// Error policy:
//   - permanent (4xx other than 429, malformed JSON, schema change): skip the
//     day, count it. After N consecutive permanent errors → exit non-zero so
//     the operator notices the API contract changed.
//   - rate-limited (429): honor Retry-After, otherwise exponential backoff
//     capped at 5 min, then retry the same day.
//   - transient (5xx, timeouts, conn refused): exponential backoff capped at
//     60s, up to maxAttempts. After exhaustion, count as a day-failure, log,
//     pause, continue.
//
// Lifecycle:
//   - SIGINT/SIGTERM: cancel context, flush cache, exit 0.
//   - Each request: 1.1s spacing on success path. 429 backoffs are added on
//     top, no permanent rate penalty.
//   - Cache flushed every 50 days, on graceful shutdown, and on each
//     day-level failure.
//
// Usage (from learning_tracker/):
//   go run ./tool/sefaria_fetch
//   go run ./tool/sefaria_fetch --start=2028-02-09
//   go run ./tool/sefaria_fetch --test=2026-05-07     # single day, prints, no write
//   go run ./tool/sefaria_fetch --refresh             # re-fetch everything
//   go build -o ../bin/sefaria_fetch ./tool/sefaria_fetch
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	cachePath           = "tool/data/sefaria_calendar_cache.json"
	defaultStart        = "2024-01-01"
	defaultEnd          = "2032-12-31"
	requestSpacing      = 1100 * time.Millisecond
	flushEvery          = 50
	maxAttempts         = 8
	requestTimeout      = 30 * time.Second
	rateLimitMaxBackoff = 5 * time.Minute
	transientMaxBackoff = 60 * time.Second
	rateLimitBaseSleep  = 30 * time.Second
	transientBaseSleep  = 2 * time.Second
	dayFailurePause     = 60 * time.Second
	// Circuit-breaker thresholds — bail with non-zero so a launcher knows
	// something is wrong and stops respawning blindly.
	maxConsecutivePermanent = 10
	maxConsecutiveDayFails  = 25
	// Suspicious-zero-results threshold (calendar API returning empty
	// calendar_items for many days in a row indicates schema change).
	maxConsecutiveZeroResults = 15
)

// titleToKey maps Sefaria's calendar item title (English) to our program-key.
// Anything not in this map is silently skipped.
var titleToKey = map[string]string{
	"Daf Yomi":                  "daf_yomi",
	"Daily Mishnah":             "daily_mishnah",
	"Daily Rambam":              "daily_rambam",
	"Daily Rambam (3 Chapters)": "daily_rambam_3",
	"Daf a Week":                "daf_a_week",
	"Halakhah Yomit":            "halakhah_yomit",
	"Arukh HaShulchan Yomi":     "arukh_hashulchan_yomi",
	"Tanakh Yomi":               "tanakh_yomi",
	"Yerushalmi Yomi":           "yerushalmi_yomi",
	"Nach Yomi":                 "nach_yomi",
	"Chofetz Chaim":             "chofetz_chaim_daily",
	"Kitzur Shulchan Arukh":     "kitzur_shulchan_aruch_yomi",
}

// Ref is the {en, he} pair for a single program on a single day. The JSON
// tags match the existing Dart-written cache; `he` is omitted when empty so
// we don't write `"he": ""` for days where Sefaria has no Hebrew form.
type Ref struct {
	En string `json:"en"`
	He string `json:"he,omitempty"`
}

// Cache: date -> programKey -> Ref. Go's encoding/json marshals string-keyed
// maps in sorted order, so writing this directly produces the same
// deterministic output the Dart fetcher produces by hand-sorting.
type Cache map[string]map[string]Ref

// apiResp is the slice of /api/calendars we care about.
type apiResp struct {
	CalendarItems []struct {
		Title        map[string]string `json:"title"`
		Ref          *string           `json:"ref"`
		DisplayValue map[string]string `json:"displayValue"`
	} `json:"calendar_items"`
}

// rateLimitError is returned when Sefaria returns 429.
type rateLimitError struct {
	retryAfter time.Duration
}

func (e *rateLimitError) Error() string {
	return fmt.Sprintf("rate limited (retry-after: %s)", e.retryAfter)
}

// permanentError is non-retriable: 4xx (except 429), malformed JSON, etc.
type permanentError struct {
	msg string
}

func (e *permanentError) Error() string { return e.msg }

func main() {
	var (
		startFlag = flag.String("start", "", "override start date (YYYY-MM-DD)")
		endFlag   = flag.String("end", "", "override end date (YYYY-MM-DD)")
		refresh   = flag.Bool("refresh", false, "ignore existing cache, refetch all days")
		testDay   = flag.String("test", "", "fetch one day, print result, do not write cache")
		verbose   = flag.Bool("v", false, "verbose retry logging")
		spacing   = flag.Duration("spacing", requestSpacing, "request spacing between successful calls")
	)
	flag.Parse()

	rand.Seed(time.Now().UnixNano())

	client := newHTTPClient()

	if *testDay != "" {
		runTestMode(client, *testDay, *verbose)
		return
	}

	start, err := time.Parse("2006-01-02", coalesce(*startFlag, defaultStart))
	if err != nil {
		fail("invalid --start: %v", err)
	}
	end, err := time.Parse("2006-01-02", coalesce(*endFlag, defaultEnd))
	if err != nil {
		fail("invalid --end: %v", err)
	}
	if end.Before(start) {
		fail("end %s is before start %s", end.Format("2006-01-02"), start.Format("2006-01-02"))
	}

	cache := Cache{}
	if !*refresh {
		c, err := loadCache(cachePath)
		if err != nil {
			fail("load cache: %v", err)
		}
		cache = c
	}

	all := datesBetween(start, end)
	missing := make([]string, 0, len(all))
	for _, d := range all {
		if _, ok := cache[d]; !ok {
			missing = append(missing, d)
		}
	}
	logf("Loaded %d cached days. Need to fetch %d / %d days (target ~%.2f req/s).",
		len(cache), len(missing), len(all), float64(time.Second)/float64(*spacing))
	if len(missing) == 0 {
		logf("Cache is complete.")
		return
	}

	ctx, cancel := signalContext()
	defer cancel()

	began := time.Now()
	var (
		done                int
		dayFailures         int
		consecPerm          int
		consecDayFails      int
		consecZeroResults   int
		lastSavedFailureLog time.Time
	)

	for i, date := range missing {
		if ctx.Err() != nil {
			logf("Cancelled — flushing %d days then exiting.", len(cache))
			break
		}

		entry, err := fetchDay(ctx, client, date, *verbose)
		if err != nil {
			if errors.Is(err, context.Canceled) {
				break
			}
			dayFailures++
			consecDayFails++
			var perm *permanentError
			if errors.As(err, &perm) {
				consecPerm++
				errf("  %s PERMANENT %v (consec perm=%d)", date, err, consecPerm)
				if consecPerm >= maxConsecutivePermanent {
					_ = writeCache(cachePath, cache)
					fail("circuit breaker: %d consecutive permanent errors — Sefaria API contract may have changed", consecPerm)
				}
			} else {
				errf("  %s ABANDONED after %d retries: %v", date, maxAttempts, err)
			}
			if consecDayFails >= maxConsecutiveDayFails {
				_ = writeCache(cachePath, cache)
				fail("circuit breaker: %d consecutive day failures — bailing", consecDayFails)
			}
			if time.Since(lastSavedFailureLog) > 30*time.Second {
				if err := writeCache(cachePath, cache); err != nil {
					errf("  WARN: cache write failed: %v", err)
				}
				lastSavedFailureLog = time.Now()
			}
			select {
			case <-ctx.Done():
				goto flush
			case <-time.After(dayFailurePause):
			}
			continue
		}

		// Reset consecutive failure counters on success.
		consecPerm = 0
		consecDayFails = 0

		if len(entry) == 0 {
			consecZeroResults++
			if consecZeroResults >= maxConsecutiveZeroResults {
				_ = writeCache(cachePath, cache)
				fail("circuit breaker: %d consecutive days with 0 mapped programs — title-to-key map may be stale or API shape changed", consecZeroResults)
			}
		} else {
			consecZeroResults = 0
		}

		cache[date] = entry
		done++
		if done%flushEvery == 0 || i == len(missing)-1 {
			if err := writeCache(cachePath, cache); err != nil {
				errf("  WARN: cache write failed: %v", err)
			}
			elapsed := time.Since(began)
			rate := float64(done) / elapsed.Seconds()
			remaining := len(missing) - done
			eta := time.Duration(float64(remaining)/rate*float64(time.Second)).Truncate(time.Second)
			logf("  %d/%d (%.2f req/s, %s elapsed, ETA %s, fails=%d)",
				done, len(missing), rate, elapsed.Truncate(time.Second), eta, dayFailures)
		}

		select {
		case <-ctx.Done():
			goto flush
		case <-time.After(*spacing):
		}
	}

flush:
	if err := writeCache(cachePath, cache); err != nil {
		fail("final cache write: %v", err)
	}
	logf("DONE — %d days cached, %d day failures.", len(cache), dayFailures)
	if dayFailures > 0 {
		os.Exit(2)
	}
}

func runTestMode(client *http.Client, date string, verbose bool) {
	if _, err := time.Parse("2006-01-02", date); err != nil {
		fail("invalid --test date: %v", err)
	}
	ctx, cancel := signalContext()
	defer cancel()
	entry, err := fetchDay(ctx, client, date, verbose)
	if err != nil {
		fail("test fetch %s: %v", date, err)
	}
	out, err := json.MarshalIndent(map[string]map[string]Ref{date: entry}, "", "  ")
	if err != nil {
		fail("encode test result: %v", err)
	}
	fmt.Println(string(out))
	logf("test OK — %d programs", len(entry))
}

func newHTTPClient() *http.Client {
	return &http.Client{
		Timeout: requestTimeout,
		Transport: &http.Transport{
			MaxIdleConns:        4,
			MaxIdleConnsPerHost: 4,
			IdleConnTimeout:     90 * time.Second,
		},
	}
}

func loadCache(path string) (Cache, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return Cache{}, nil
	}
	if err != nil {
		return nil, err
	}
	if len(data) == 0 {
		return Cache{}, nil
	}
	var raw map[string]map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("parse cache: %w", err)
	}
	out := make(Cache, len(raw))
	for date, progs := range raw {
		entry := make(map[string]Ref, len(progs))
		allHaveHe := true
		for k, v := range progs {
			// Skip legacy en-only string shape — we want en+he, so trigger refetch.
			if len(v) > 0 && v[0] == '"' {
				allHaveHe = false
				continue
			}
			var r Ref
			if err := json.Unmarshal(v, &r); err != nil {
				return nil, fmt.Errorf("parse cache entry %s/%s: %w", date, k, err)
			}
			if r.En == "" {
				continue
			}
			if r.He == "" {
				allHaveHe = false
			}
			entry[k] = r
		}
		if len(entry) > 0 && allHaveHe {
			out[date] = entry
		}
	}
	return out, nil
}

func writeCache(path string, cache Cache) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp := path + ".tmp"
	f, err := os.Create(tmp)
	if err != nil {
		return err
	}
	enc := json.NewEncoder(f)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	if err := enc.Encode(cache); err != nil {
		_ = f.Close()
		_ = os.Remove(tmp)
		return err
	}
	if err := f.Sync(); err != nil {
		_ = f.Close()
		_ = os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, path)
}

func fetchDay(ctx context.Context, client *http.Client, date string, verbose bool) (map[string]Ref, error) {
	parts := strings.Split(date, "-")
	if len(parts) != 3 {
		return nil, &permanentError{fmt.Sprintf("bad date %q", date)}
	}
	url := fmt.Sprintf(
		"https://www.sefaria.org/api/calendars?diaspora=1&year=%s&month=%s&day=%s",
		parts[0], parts[1], parts[2],
	)

	var lastErr error
	for attempt := 0; attempt < maxAttempts; attempt++ {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		entry, err := tryFetchDay(ctx, client, url)
		if err == nil {
			return entry, nil
		}
		lastErr = err

		var perm *permanentError
		if errors.As(err, &perm) {
			return nil, perm
		}

		var rl *rateLimitError
		var wait time.Duration
		switch {
		case errors.As(err, &rl):
			if rl.retryAfter > 0 {
				wait = rl.retryAfter
			} else {
				wait = backoff(rateLimitBaseSleep, attempt, rateLimitMaxBackoff)
			}
			errf("  %s 429 — sleeping %s (attempt %d/%d)", date, wait.Truncate(time.Second), attempt+1, maxAttempts)
		default:
			wait = backoff(transientBaseSleep, attempt, transientMaxBackoff)
			if verbose {
				errf("  %s transient %v — retry in %s (attempt %d/%d)", date, err, wait.Truncate(time.Second), attempt+1, maxAttempts)
			}
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(wait):
		}
	}
	return nil, fmt.Errorf("after %d attempts: %w", maxAttempts, lastErr)
}

func tryFetchDay(ctx context.Context, client *http.Client, url string) (map[string]Ref, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, &permanentError{err.Error()}
	}
	req.Header.Set("User-Agent", "learning-tracker-seed-build/1.0")
	req.Header.Set("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	switch {
	case resp.StatusCode == 429:
		_, _ = io.Copy(io.Discard, resp.Body)
		return nil, &rateLimitError{retryAfter: parseRetryAfter(resp.Header.Get("Retry-After"))}
	case resp.StatusCode == 200:
		// fall through
	case resp.StatusCode >= 500:
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	case resp.StatusCode >= 400:
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, &permanentError{fmt.Sprintf("HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))}
	default:
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	var ar apiResp
	if err := json.NewDecoder(resp.Body).Decode(&ar); err != nil {
		return nil, &permanentError{fmt.Sprintf("decode response: %v", err)}
	}

	out := make(map[string]Ref)
	for _, item := range ar.CalendarItems {
		titleEn := item.Title["en"]
		key, ok := titleToKey[titleEn]
		if !ok {
			continue
		}
		if item.Ref == nil || *item.Ref == "" {
			continue
		}
		// Sefaria's /api/calendars puts the user-facing Hebrew form in
		// displayValue.he (e.g. "בבא קמא ס׳") — heRef is null for calendar items.
		ref := Ref{En: *item.Ref}
		if he := item.DisplayValue["he"]; he != "" {
			ref.He = he
		}
		out[key] = ref
	}
	return out, nil
}

// parseRetryAfter accepts both the seconds-integer and HTTP-date forms.
func parseRetryAfter(h string) time.Duration {
	if h == "" {
		return 0
	}
	h = strings.TrimSpace(h)
	if secs, err := strconv.Atoi(h); err == nil && secs >= 0 {
		return time.Duration(secs) * time.Second
	}
	if t, err := http.ParseTime(h); err == nil {
		if d := time.Until(t); d > 0 {
			return d
		}
	}
	return 0
}

// backoff = base * 2^attempt with ±20% jitter, capped at ceiling.
func backoff(base time.Duration, attempt int, ceiling time.Duration) time.Duration {
	d := base << attempt
	if d <= 0 || d > ceiling {
		d = ceiling
	}
	jitter := time.Duration(rand.Int63n(int64(d) / 5))
	if rand.Intn(2) == 0 {
		return d - jitter
	}
	return d + jitter
}

func datesBetween(start, end time.Time) []string {
	out := make([]string, 0, int(end.Sub(start).Hours()/24)+1)
	for d := start; !d.After(end); d = d.AddDate(0, 0, 1) {
		out = append(out, d.Format("2006-01-02"))
	}
	return out
}

func signalContext() (context.Context, context.CancelFunc) {
	ctx, cancel := context.WithCancel(context.Background())
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		sig := <-c
		logf("got %s — cancelling…", sig)
		cancel()
	}()
	return ctx, cancel
}

func logf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "[%s] %s\n", time.Now().Format("15:04:05"), fmt.Sprintf(format, args...))
}

func errf(format string, args ...any) { logf(format, args...) }

func fail(format string, args ...any) {
	logf(format, args...)
	os.Exit(1)
}

func coalesce(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
