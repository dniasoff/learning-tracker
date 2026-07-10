#!/usr/bin/env python3
"""One-shot account-quota switch check, run by system cron every 5 minutes.
Zero Claude inference quota. Switches the active OAuth login to the freshest
usable account BEFORE the current one exhausts.

GENTLE PROBING (critical): probing a DORMANT account's status triggers an
OAuth token refresh; doing that every 5 min hammers the refresh endpoint and
pins the 429 rate-limit (which throttled 3 accounts into a ~6h backoff on
2026-07-10). So this script probes ONLY the ACTIVE account each tick (the
tool mirrors the active login locally - no token-endpoint call), and probes
the others ONLY when the active account is actually near its limit and a
switch is needed. Dormant accounts are otherwise left completely alone so a
throttle can decay.

Committed to the repo (survives /tmp wipes); the crontab points here.
Threshold 80% session gives a 20% buffer for the 5-minute polling gap."""
import json
import subprocess
import time

LOG = '/home/daniel/.claude-acct-switch.log'
SWITCH_AT = 80.0
NEAR_DEATH = 92.0
MIN_GAIN = 10.0
WEEKLY_CAP = 92.0


def log(m):
    try:
        with open(LOG, 'a') as f:
            f.write(time.strftime('%Y-%m-%d %H:%M:%S') + '  ' + m + '\n')
    except Exception:
        pass


def sh(args, timeout=60):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout)


def account_names():
    out = sh(['claude-account', 'list'], timeout=30).stdout
    return [line.replace('*', ' ', 1).split()[0] for line in out.splitlines() if line.split()]


def active_name():
    out = sh(['claude-account', 'list'], timeout=30).stdout
    for line in out.splitlines():
        if line.lstrip().startswith('*'):
            toks = line.replace('*', ' ', 1).split()
            if toks:
                return toks[0]
    return None


def acct_status(name):
    """Status for ONE account. Safe (no refresh) for the active account."""
    r = sh(['claude-account', 'status', name, '--json'], timeout=60)
    return json.loads(r.stdout)[0]


def sp(a):
    try:
        return float(a['session']['percent'])
    except Exception:
        return None


def wp(a):
    try:
        return float(a['weekly']['percent'])
    except Exception:
        return None


def main():
    an = active_name()
    if not an:
        log('no active account found')
        return
    try:
        a = acct_status(an)
    except Exception as e:
        log('active(%s) status unreadable: %s' % (an, str(e)[:80]))
        return
    s, w = sp(a), wp(a)
    if s is None:
        log('active(%s) usage unreadable' % an)
        return
    if s < SWITCH_AT and (w is None or w < WEEKLY_CAP):
        log('ok active=%s s=%.0f w=%s (active-only probe)' % (an, s, ('%.0f' % w) if w is not None else '?'))
        return
    # Active account is near its limit -> now (and only now) probe the others.
    cands = []
    for n in account_names():
        if n == an:
            continue
        try:
            o = acct_status(n)
            if sp(o) is not None and (wp(o) is None or wp(o) < WEEKLY_CAP):
                cands.append(o)
        except Exception:
            pass  # dormant/throttled account - leave it alone
    cands.sort(key=lambda x: (sp(x), wp(x) if wp(x) is not None else 0.0))
    best = cands[0] if cands else None
    if best is not None and (sp(best) <= s - MIN_GAIN or s >= NEAR_DEATH):
        r = sh(['claude-account', 'use', best['name']])
        ok = (r.returncode == 0)
        log('SWITCH %s(s%.0f/w%s) -> %s(s%.0f) %s' % (
            an, s, ('%.0f' % w) if w is not None else '?', best['name'], sp(best),
            'ok' if ok else ('FAILED ' + (r.stderr or '')[:60])))
    else:
        lo = ('%s s%.0f' % (best['name'], sp(best))) if best else 'none-usable'
        log('SATURATED active=%s s=%.0f best=%s (waiting for reset/backoff-decay)' % (an, s, lo))


if __name__ == '__main__':
    main()
