# Collectors

Collectors are executable scripts/programs that emit **exactly one non-empty line** of JSON to stdout.

## Output contract

Each collector **must** print one JSON object with the following keys:

- `name` (string): short, stable label (used as an identifier)
- `value` (string | number | boolean | null): current value
- `enabled` (boolean): whether this item is eligible for display

Example:

{"name":"TEMP","value":"42C","enabled":true}

## Behavioral requirements

- **Exactly one line:** collectors must emit exactly one non-empty line on stdout. Any other stdout output will be treated as invalid.
- **Diagnostics to stderr:** write errors and debugging information to stderr. The pipeline appends stderr to a per-collector log file.
- **Do not prompt:** collectors must be safe to run unattended (cron/systemd). They must not prompt for passwords, host key confirmation, or interactive input.

## SSH-based collectors (non-interactive requirements)

SSH is sensitive to whether a TTY and stdin are available. Collectors are executed non-interactively by the pipeline and may also run under cron; a script that “works when run by hand” can hang or fail under automation unless SSH is configured to be strictly non-interactive.

For SSH-based collectors, use a hardened invocation that:

1. Never reads from stdin
2. Never allocates a TTY
3. Never falls back to password or keyboard-interactive authentication
4. Fails fast on connection issues
5. Avoids interactive host key prompts

Recommended baseline:

ssh -n -T -q -i "$KEY" \
  -o IdentitiesOnly=yes \
  -o BatchMode=yes \
  -o PreferredAuthentications=publickey \
  -o PasswordAuthentication=no \
  -o KbdInteractiveAuthentication=no \
  -o NumberOfPasswordPrompts=0 \
  -o RequestTTY=no \
  -o ConnectTimeout=3 \
  -o ConnectionAttempts=1 \
  -o StrictHostKeyChecking=accept-new \
  "$USER@$HOST" <remote-command>

### Notes on key options

- `-n`: redirects stdin from `/dev/null` to prevent blocking on input.
- `-T` and `-o RequestTTY=no`: prevents TTY allocation, avoiding terminal-related failures and interactive prompt behavior.
- `-o BatchMode=yes` and `-o NumberOfPasswordPrompts=0`: disables interactive prompts entirely (fail fast instead).
- `-o PreferredAuthentications=publickey` plus `-o PasswordAuthentication=no` and `-o KbdInteractiveAuthentication=no`: ensures SSH does not try password/keyboard-interactive methods that can hang or prompt.
- `-o ConnectTimeout=3` and `-o ConnectionAttempts=1`: bounds time spent on connection establishment and retries.
- `-o StrictHostKeyChecking=accept-new`: avoids host key confirmation prompts on first contact while still validating known hosts thereafter.

## Host key handling

For environments where host keys should be pinned (recommended for stable targets), pre-seed known hosts and use strict checking.

Pre-seed:

ssh-keyscan -H "$HOST" >> "$HOME/.ssh/known_hosts"

Then use:

-o StrictHostKeyChecking=yes

## Naming and display constraints

- Keep `name` short and stable.
- Keep `value` concise.
- The sender clamps display fields to **6 characters** for the OLED.

