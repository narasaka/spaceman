#!/bin/zsh
# Live before/after harness for "clicking a notification focuses the window".
# Runs a built spaceman-agent against an isolated SPACEMAN_APPLICATION_SUPPORT.
# Workspace 7: ReproR "R" (focused last) + Ghostty "G" (notifier).
# Workspace 8: ReproR "O" (the app you are in when the banner arrives).
# Expected: clicking G's banner from workspace 8 shows workspace 7 with G focused.
set -u
SP=${0:A:h}
VARIANT=$1                      # base | fix
BIN=$SP/$VARIANT
STATE=$SP/state-$VARIANT
rm -rf "$STATE"; mkdir -p "$STATE"; chmod 700 "$STATE"
# control.sock must fit in sun_path; a short symlink points into the scratchpad.
LINK=/private/tmp/claude-501/sm-$VARIANT
ln -sfn "$STATE" "$LINK"
export SPACEMAN_APPLICATION_SUPPORT=$LINK
export SPACEMAN_CONFIG=$STATE/config.toml
printf 'version = 1\n' > "$SPACEMAN_CONFIG"
printf '1\n' > "$SPACEMAN_APPLICATION_SUPPORT/onboarding-complete"
S=$BIN/spaceman
LOG=$SPACEMAN_APPLICATION_SUPPORT/agent.log
GO=$SP/go-$VARIANT-$$
OUT=$SP/live-$VARIANT
state() { $S ctl debug | python3 -c 'import json,sys; d=json.load(sys.stdin); f=d.get("focused") or {}; print("active", d["active_workspaces"], "frontmost pid", (d.get("frontmost") or {}).get("pid"), "focused pid", f.get("app",{}).get("pid"), "window", f.get("window_id"))'; }
active() { $S ctl status | python3 -c 'import json,sys; print(json.load(sys.stdin)["active_workspaces"][0])'; }
fpid() { $S ctl debug | python3 -c 'import json,sys; d=json.load(sys.stdin); print(((d.get("focused") or {}).get("app") or {}).get("pid"))'; }
front() { osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $1) to true"; }
place() { # move pid $1's focused window to workspace $2
  [ "$(fpid)" = "$1" ] || { front $1; sleep 1; }
  [ "$(fpid)" = "$1" ] || { echo "cannot focus $1"; exit 1; }
  $S ctl move $2 >/dev/null; sleep 1; }

pgrep -x spaceman-agent >/dev/null && { echo "another spaceman-agent is running; stop it first"; exit 1; }
"$BIN/spaceman-agent" &
AGENT=$!
for i in {1..40}; do $S ctl status 2>/dev/null | grep -q '"mode":"automatic"' && break; sleep 0.25; done
echo "[$VARIANT] agent $AGENT: $($S ctl status)"
sleep 1.5
open -n "$SP/ReproR.app"; sleep 2.5; R=$(pgrep -n -x ReproR); place $R 7
open -na /Applications/Ghostty.app --args --confirm-close-surface=false --quit-after-last-window-closed=true --title=spaceman-G \
  -e /bin/zsh -c "while [ ! -e '$GO' ]; do sleep 0.2; done; printf '\e]9;Spaceman repro G\a'; sleep 900"
sleep 2.5; G=$(pgrep -n -x ghostty); place $G 7
open -n "$SP/ReproR.app"; sleep 2.5; O=$(pgrep -n -x ReproR); place $O 8
echo "R=$R G=$G O=$O"
$S ctl switch 7 >/dev/null; sleep 1.5
front $R; sleep 1.5
echo "on 7, R focused:   $(state)"
$S ctl switch 8 >/dev/null; sleep 1.5
echo "on 8, O focused:   $(state)"
touch "$GO"
for i in {1..40}; do $SP/nc list 2>/dev/null | grep -q "Spaceman repro G" && break; sleep 0.25; done
sleep 0.8  # let the banner finish sliding in
screencapture -x "$OUT-1-banner.png"
$SP/nc click "Spaceman repro G" | grep -v "^ \|^AX"
for t in 0.3 0.7 1.5 3; do sleep $t; echo "t+$t: $(state)"; done
screencapture -x "$OUT-2-after.png"
RESULT=$([ "$(fpid)" = "$G" ] && [ "$(active)" = 7 ] && echo PASS || echo FAIL)
echo "[$VARIANT] RESULT: active=$(active) focused pid=$(fpid) (G=$G R=$R) -> $RESULT"
echo "--- [$VARIANT] agent.log (focus follow / switch) ---"
grep -E "focus follow|switch:|switch complete|bound" "$LOG" | sed -E 's/PhysicalWindowId \{ app: AppInstanceId \{ pid: ([0-9]+), launched_at: [0-9]+ \}, window_id: ([0-9]+) \}/win(\1:\2)/g; s/AppInstanceId \{ pid: ([0-9]+), launched_at: [0-9]+ \}/app(\1)/g' | tail -12
kill $G $R $O 2>/dev/null; rm -f "$GO"; sleep 1
$S ctl quit >/dev/null 2>&1
for i in {1..40}; do kill -0 $AGENT 2>/dev/null || break; sleep 0.25; done
kill -0 $AGENT 2>/dev/null && { echo "agent still running"; kill -TERM $AGENT; }
echo "[$VARIANT] parked after quit: $(cat $SPACEMAN_APPLICATION_SUPPORT/parked-windows.json 2>/dev/null | head -c 200)"
