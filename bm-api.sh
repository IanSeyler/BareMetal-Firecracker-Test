#!/usr/bin/env bash
# bm-api.sh -- a small CLI over the BareMetal VPS API, authenticated with a
# self-service API key instead of a browser session. Create a key first from
# the dashboard (or `POST /api/api-keys` while signed in) -- see the "API
# keys" section of docs/api.md.
#
# By default, output is just the field(s) you need (e.g. `instances create`
# prints the new instance's id and status) -- pass -v/--verbose on any
# command to print the full JSON response instead.
#
# Usage:
#   BM_API_KEY=bmvps_... ./bm-api.sh [-v|--verbose] <command> [args...]
#
# Config (env vars):
#   BM_API_KEY   Bearer token from POST /api/api-keys. Required.
#   BM_API_BASE  Base URL of the backend. Default: https://baremetal.returninfinity.com
#
# Commands:
#   images list
#   images upload <label> <file>
#   images rm <image-id>
#
#   instances list
#   instances show <instance-id>
#   instances create <name> <vcpu> <ram-mib> <image-id>
#   instances start|stop|reboot|suspend|resume|snapshot|restore <instance-id>
#   instances rm <instance-id>
#   instances logs <instance-id>
#
#   tasks show <task-id>
#
# Every command that enqueues a ProvisioningTask (create, start, stop,
# reboot, suspend, resume, snapshot, restore, rm, logs) polls
# GET /api/tasks/:id until it settles before printing anything -- these are
# asynchronous on the server, so this script hides that instead of leaving
# you to poll by hand.
#
# An API key only works against /api/images, /api/instances, /api/tasks, and
# /api/limits (never billing, account, or admin routes), and never needs an
# X-CSRF-Token header -- see docs/threat-model.md's "API keys" section for why.

set -euo pipefail

BM_API_BASE="${BM_API_BASE:-https://baremetal.returninfinity.com}"
POLL_INTERVAL_SECONDS="${BM_API_POLL_INTERVAL_SECONDS:-1}"
POLL_MAX_ATTEMPTS="${BM_API_POLL_MAX_ATTEMPTS:-60}"

VERBOSE=0
STATUS=""
BODY=""

usage() {
  # Print this script's own header comment (everything between the shebang
  # and the `set -euo pipefail` line above) as the usage text.
  sed -n '2,/^set -euo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

fail() {
  echo "error: $*" >&2
  exit 1
}

require_deps() {
  command -v curl >/dev/null 2>&1 || fail "curl is required"
  command -v jq >/dev/null 2>&1 || fail "jq is required"
}

require_api_key() {
  [ -n "${BM_API_KEY:-}" ] || fail "BM_API_KEY is not set (create one via the dashboard or POST /api/api-keys)"
}

# call METHOD PATH [extra curl args...] -- sets STATUS/BODY as a side effect.
call() {
  local method="$1" path="$2"
  shift 2
  local body_file
  body_file="$(mktemp)"
  STATUS="$(
    curl -sS -o "$body_file" -w '%{http_code}' -X "$method" \
      -H "Authorization: Bearer ${BM_API_KEY}" \
      "${BM_API_BASE}${path}" "$@"
  )"
  BODY="$(cat "$body_file")"
  rm -f "$body_file"
}

# Exits with an error message pulled from the JSON {"error": "..."} body if
# the last `call` didn't return a 2xx status. In verbose mode, also dumps the
# full error body (e.g. per-field validation `details`).
check_ok() {
  case "$STATUS" in
    2*) return 0 ;;
  esac
  local message
  message="$(echo "$BODY" | jq -r '.error // empty' 2>/dev/null)"
  if [ "$VERBOSE" = "1" ] && [ -n "$BODY" ]; then
    echo "$BODY" | jq . >&2 2>/dev/null || echo "$BODY" >&2
  fi
  fail "HTTP ${STATUS}: ${message:-$BODY}"
}

# emit JQ_FILTER -- prints the full $BODY as pretty JSON in verbose mode,
# otherwise runs JQ_FILTER (raw output) over it for the concise view.
emit() {
  if [ "$VERBOSE" = "1" ]; then
    [ -n "$BODY" ] && echo "$BODY" | jq .
  else
    echo "$BODY" | jq -r "$1"
  fi
}

# print_lifecycle_result INSTANCE_ID -- call after wait_for_task for an
# instance lifecycle action ($BODY is the final task JSON at that point,
# which carries instanceStatus but not the instance's own id).
print_lifecycle_result() {
  if [ "$VERBOSE" = "1" ]; then
    echo "$BODY" | jq .
  else
    echo "id: $1"
    echo "status: $(echo "$BODY" | jq -r .instanceStatus)"
  fi
}

# wait_for_task TASK_ID LABEL -- polls until SUCCEEDED/FAILED. On return,
# $BODY is the final task JSON. Exits non-zero if the task failed or timed out.
wait_for_task() {
  local task_id="$1" label="$2" attempt=0 status
  echo "${label}: task ${task_id}..." >&2
  while [ "$attempt" -lt "$POLL_MAX_ATTEMPTS" ]; do
    call GET "/api/tasks/${task_id}"
    check_ok
    status="$(echo "$BODY" | jq -r .status)"
    if [ "$status" = "SUCCEEDED" ]; then
      return 0
    fi
    if [ "$status" = "FAILED" ]; then
      fail "task ${task_id} failed: $(echo "$BODY" | jq -r '.lastError // "unknown error"')"
    fi
    sleep "$POLL_INTERVAL_SECONDS"
    attempt=$((attempt + 1))
  done
  fail "timed out waiting for task ${task_id} to finish"
}

# lifecycle_action ACTION INSTANCE_ID -- POSTs /api/instances/:id/ACTION,
# waits for the resulting task, and prints the result.
lifecycle_action() {
  local action="$1" instance_id="$2"
  call POST "/api/instances/${instance_id}/${action}"
  check_ok
  wait_for_task "$(echo "$BODY" | jq -r .taskId)" "$action"
  print_lifecycle_result "$instance_id"
}

cmd_images() {
  local sub="${1:-}"
  case "$sub" in
    list)
      call GET "/api/images"
      check_ok
      emit '.images[] | "\(.id)\t\(.label)\t\(if .mine then "yours" else "shared" end)"'
      ;;
    upload)
      local label="${2:?usage: images upload <label> <file>}" file="${3:?usage: images upload <label> <file>}"
      [ -f "$file" ] || fail "no such file: $file"
      call POST "/api/images" -F "label=${label}" -F "file=@${file}"
      check_ok
      emit '"id: \(.id)\nlabel: \(.label)"'
      ;;
    rm)
      local image_id="${2:?usage: images rm <image-id>}"
      call DELETE "/api/images/${image_id}"
      check_ok
      echo "deleted ${image_id}"
      ;;
    *)
      fail "usage: images {list|upload|rm} ..."
      ;;
  esac
}

cmd_instances() {
  local sub="${1:-}"
  case "$sub" in
    list)
      call GET "/api/instances"
      check_ok
      emit '.instances[] | "\(.id)\t\(.name)\t\(.status)"'
      ;;
    show)
      local id="${2:?usage: instances show <instance-id>}"
      call GET "/api/instances/${id}"
      check_ok
      emit '"id: \(.id)\nname: \(.name)\nstatus: \(.status)\nip: \(.network.guestIp // "-")"'
      ;;
    create)
      local name="${2:?usage: instances create <name> <vcpu> <ram-mib> <image-id>}"
      local vcpu="${3:?usage: instances create <name> <vcpu> <ram-mib> <image-id>}"
      local ram_mib="${4:?usage: instances create <name> <vcpu> <ram-mib> <image-id>}"
      local image_id="${5:?usage: instances create <name> <vcpu> <ram-mib> <image-id>}"
      [ "$ram_mib" -ge 4 ] 2>/dev/null || fail "ram-mib must be at least 4 (got '${ram_mib}')"
      local payload
      payload="$(jq -n --arg name "$name" --argjson vcpu "$vcpu" --argjson ramMib "$ram_mib" --arg vmImageId "$image_id" \
        '{name: $name, vcpu: $vcpu, ramMib: $ramMib, vmImageId: $vmImageId}')"
      call POST "/api/instances" -H "Content-Type: application/json" -d "$payload"
      check_ok
      local instance_id
      instance_id="$(echo "$BODY" | jq -r .instance.id)"
      wait_for_task "$(echo "$BODY" | jq -r .taskId)" "create"
      call GET "/api/instances/${instance_id}"
      check_ok
      emit '"id: \(.id)\nstatus: \(.status)"'
      ;;
    start|stop|reboot|suspend|resume|snapshot|restore)
      local id="${2:?usage: instances ${sub} <instance-id>}"
      lifecycle_action "$sub" "$id"
      ;;
    rm)
      local id="${2:?usage: instances rm <instance-id>}"
      call DELETE "/api/instances/${id}"
      check_ok
      wait_for_task "$(echo "$BODY" | jq -r .taskId)" "rm"
      print_lifecycle_result "$id"
      ;;
    logs)
      local id="${2:?usage: instances logs <instance-id>}"
      call POST "/api/instances/${id}/fetch-logs"
      check_ok
      wait_for_task "$(echo "$BODY" | jq -r .taskId)" "logs"
      if [ "$VERBOSE" = "1" ]; then
        echo "$BODY" | jq .
      elif [ "$(echo "$BODY" | jq -r '.resultPayload.exists')" = "true" ]; then
        echo "$BODY" | jq -r '.resultPayload.logContent'
        if [ "$(echo "$BODY" | jq -r '.resultPayload.truncated')" = "true" ]; then
          echo "(showing only the most recent portion of the log)" >&2
        fi
      else
        echo "(no log file exists yet for this instance)" >&2
      fi
      ;;
    *)
      fail "usage: instances {list|show|create|start|stop|reboot|suspend|resume|snapshot|restore|rm|logs} ..."
      ;;
  esac
}

cmd_tasks() {
  local sub="${1:-}"
  case "$sub" in
    show)
      local id="${2:?usage: tasks show <task-id>}"
      call GET "/api/tasks/${id}"
      check_ok
      emit '"id: \(.id)\ntype: \(.type)\nstatus: \(.status)\(if .status == "FAILED" then "\nerror: \(.lastError)" else "" end)"'
      ;;
    *)
      fail "usage: tasks show <task-id>"
      ;;
  esac
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help|help)
        usage
        exit 0
        ;;
      -v|--verbose)
        VERBOSE=1
        shift
        ;;
      -*)
        usage >&2
        fail "unknown option: $1"
        ;;
      *)
        break
        ;;
    esac
  done

  local command="${1:-}"
  if [ -z "$command" ]; then
    usage
    exit 0
  fi
  shift

  require_deps
  require_api_key

  case "$command" in
    images) cmd_images "$@" ;;
    instances) cmd_instances "$@" ;;
    tasks) cmd_tasks "$@" ;;
    *)
      usage >&2
      fail "unknown command: $command"
      ;;
  esac
}

main "$@"
