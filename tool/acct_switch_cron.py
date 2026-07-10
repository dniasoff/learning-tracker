#!/usr/bin/env python3
"""One-shot account-quota switch check, run by system cron every 5 minutes.
Zero Claude inference quota (pure claude-account CLI). Switches the active
OAuth login to the freshest usable account BEFORE the current one exhausts,
so the running delivery engine never dies on a session limit. Durable: each
cron run is independent, so a single failure self-heals on the next tick.

Committed to the repo so it survives /tmp wipes; the crontab points here.
Threshold 80% (not 86%) gives a 20% buffer for the 5-minute polling gap."""
import json
import subprocess
import time

LOG = '/home/daniel/.claude-acct-switch.log'  # outside the repo: never pollutes engine clean-tree checks
SWITCH_AT = 80.0    # rotate away from the active account at/above this session %
NEAR_DEATH = 92.0   # at/above this, take ANY lower account regardless of gain
MIN_GAIN = 10.0     # otherwise only rotate to an account this many points lower
WEEKLY_CAP = 92.0   # never rotate TO an account at/above this weekly %


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
    names = []
    for line in out.splitlines():
        toks = line.replace('*', ' ', 1).split()
        if toks:
            names.append(toks[0])
    return names


def status():
    # aggregate fast path; fall back to per-account so one expired-token
    # account (which makes the aggregate call exit non-zero) can't blind us.
    try:
        r = sh(['claude-account', 'status', '--json'], timeout=90)
        if r.returncode == 0:
            return json.loads(r.stdout)
    except Exception:
        pass
    st = []
    for n in account_names():
        try:
            r = sh(['claude-account', 'status', n, '--json'], timeout=60)
            arr = json.loads(r.stdout)
            if arr:
                st.append(arr[0])
        except Exception:
            st.append({'name': n, 'active': False, 'error': 'fetch failed'})
    return st


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
    try:
        st = status()
    except Exception as e:
        log('status error: %s' % str(e)[:120])
        return
    act = next((a for a in st if a.get('active')), None)
    if act is None or sp(act) is None:
        log('active usage unreadable; skipping this tick')
        return
    s, w = sp(act), wp(act)
    standings = ' '.join(
        ('%s=%s/%sw%s' % (a.get('name', '?'),
                          ('%.0f' % sp(a)) if sp(a) is not None else 'ERR',
                          ('%.0f' % wp(a)) if wp(a) is not None else 'ERR',
                          '*' if a.get('active') else ''))
        for a in st)
    if not ((s >= SWITCH_AT) or (w is not None and w >= WEEKLY_CAP)):
        log('ok active=%s s=%.0f w=%s | %s' % (act['name'], s, ('%.0f' % w) if w is not None else '?', standings))
        return
    cands = [a for a in st if not a.get('active') and sp(a) is not None and (wp(a) is None or wp(a) < WEEKLY_CAP)]
    cands.sort(key=lambda a: (sp(a), wp(a) if wp(a) is not None else 0.0))
    best = cands[0] if cands else None
    if best is not None and (sp(best) <= s - MIN_GAIN or s >= NEAR_DEATH):
        r = sh(['claude-account', 'use', best['name']])
        ok = (r.returncode == 0)
        log('SWITCH %s(s%.0f/w%s) -> %s(s%.0f) %s | %s' % (
            act['name'], s, ('%.0f' % w) if w is not None else '?',
            best['name'], sp(best),
            'ok' if ok else ('FAILED ' + (r.stderr or '')[:60]), standings))
    else:
        lo = ('%s s%.0f' % (best['name'], sp(best))) if best else 'none-usable'
        log('SATURATED active=%s s=%.0f best=%s | %s' % (act['name'], s, lo, standings))


if __name__ == '__main__':
    main()
