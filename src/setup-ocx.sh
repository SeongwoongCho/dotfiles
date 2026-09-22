#!/bin/bash
set -uo pipefail

#==================================================#
# opencodex (ocx) model routing
#
# Keeps model delegation on real Claude Code subagents instead of `codex exec`
# or `cursor-agent` shell-outs, and stops cursor from re-serving models a
# native provider already covers.
#
# Idempotent, and `ocx sync` silently drops custom models, so update.sh re-runs
# this after every sync.
#==================================================#

if ! command -v ocx >/dev/null 2>&1; then
    echo '[setup-ocx] ocx not installed, skipping'
    exit 0
fi

#==================================================#
# cursor models
#
# openai and anthropic are registered natively, so cursor's copies of those
# models only split the quota across two providers. What cursor alone serves --
# kimi, grok, glm, gemini, composer, muse -- is kept.
#==================================================#
CURSOR_MODELS="auto,auto-balance,auto-cost,auto-intelligence,claude-4-sonnet"
CURSOR_MODELS="$CURSOR_MODELS,composer-2.5,composer-2.5-fast"
CURSOR_MODELS="$CURSOR_MODELS,gemini-3-flash,gemini-3.1-pro,gemini-3.5-flash"
CURSOR_MODELS="$CURSOR_MODELS,gemini-3.6-flash,gemini-3.7-flash,gemini-3.8-flash"
CURSOR_MODELS="$CURSOR_MODELS,glm-5.2"
CURSOR_MODELS="$CURSOR_MODELS,gpt-5-mini,gpt-5.1,gpt-5.2,gpt-5.3-codex"
CURSOR_MODELS="$CURSOR_MODELS,gpt-5.4,gpt-5.4-mini,gpt-5.4-nano,gpt-5.5-extra"
CURSOR_MODELS="$CURSOR_MODELS,grok-4.5,grok-4.6,grok-4.7"
CURSOR_MODELS="$CURSOR_MODELS,kimi-k2.7-code,kimi-k3,muse-spark-1.3"

# cursor serves grok-4.7, but its model-list endpoint does not advertise it.
if ! ocx models list-custom 2>/dev/null | grep -q 'grok-4.7'; then
    echo '[setup-ocx] registering cursor/grok-4.7'
    ocx models add cursor grok-4.7 \
        --display-name 'Grok 4.7' \
        --context-window 500000 \
        --modalities text,image \
        --reasoning-efforts low,medium,high,xhigh \
        --default-reasoning-effort high >/dev/null || true
fi

ocx provider edit cursor --retain-models grok-4.7 >/dev/null || true
ocx models selected cursor --set "$CURSOR_MODELS" >/dev/null || true

#==================================================#
# Subagent roster
#
# ocx caps this at 5 (src/cli/agent.ts). ocx-self already covers Claude, so the
# slots buy distinct lineages: OpenAI, xAI, Moonshot, Google.
#==================================================#
ocx agent subagents set \
    gpt-6-astra,gpt-5.6-sol,cursor/grok-4.7,cursor/kimi-k3,cursor/gemini-3.1-pro \
    >/dev/null || true

#==================================================#
# Claude Code: no codex plugin
#
# codex@openai-codex answers "spawn a gpt subagent" with a Bash `codex exec` or
# `cursor-agent` shell-out, bypassing the Agent tool and ocx usage accounting.
#==================================================#
SETTINGS="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS" ]] && command -v python3 >/dev/null 2>&1; then
    python3 - "$SETTINGS" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path) as handle:
    settings = json.load(handle)

plugins = settings.setdefault("enabledPlugins", {})
if plugins.get("codex@openai-codex") is not False:
    plugins["codex@openai-codex"] = False
    with open(path, "w") as handle:
        json.dump(settings, handle, indent=2, ensure_ascii=False)
    print("[setup-ocx] disabled codex@openai-codex")
PY
fi

ocx sync >/dev/null || echo '[setup-ocx] ocx sync failed, catalog left as-is'
echo '[setup-ocx] done'
