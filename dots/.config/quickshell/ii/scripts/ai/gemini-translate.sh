#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <target_locale> [model]"
    exit 1
fi

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SHELL_CONFIG_DIR="$XDG_CONFIG_HOME/illogical-impulse"
SHELL_CONFIG_FILE="${SHELL_CONFIG_DIR}/config.json"
TRANSLATIONS_DIR="${SCRIPT_DIR}/../../translations"
TRANSLATIONS_TARGET_DIR="${SHELL_CONFIG_DIR}/translations"
SOURCE_LOCALE="en_US"
NOTIFICATION_APP_NAME="Shell"
TARGET_LOCALE="$1"
MODEL="${2:-${GEMINI_MODEL:-gemini-2.5-flash}}"

# Ensure translations keys up to date
"${TRANSLATIONS_DIR}/tools/manage-translations.sh" update -l "$SOURCE_LOCALE" --yes
mkdir -p "$TRANSLATIONS_TARGET_DIR"

# Build prompt
instruction='You are to translate the user interface of a **desktop shell**. Given a JSON object of key-value pairs, return a JSON with the same structure, with keys unchanged and values translated to '"$TARGET_LOCALE"'. Be as **concise** as possible to save screen space, and make sure terminology is relevant (e.g. "discharging" refers to the battery status).'
content=$(cat "${TRANSLATIONS_DIR}/en_US.json")
prompt_json=$(jq -n --arg prompt_text "$instruction" --arg content "$content" '$prompt_text + "\n```\n" + $content + "\n```\n"')

# Build payload
payload=$(jq -n \
    --arg prompt "$prompt_json" \
    --arg temperature "0" \
    --arg model "$MODEL" \
    '{
        contents: [{
            parts: [
                {text: $prompt}
            ]
        }],
        generationConfig: {
            temperature: ($temperature | tonumber),
            "responseMimeType": "application/json"
        }
    }'
)

# Get ProxyAPI key (you must use your ProxyAPI key; it is NOT the Google key)
# Adjust this lookup if you store the ProxyAPI key under a different secret-tool label.
API_KEY=$(secret-tool lookup 'application' 'proxyapi' || secret-tool lookup 'application' 'illogical-impulse' | jq -r '.apiKeys.proxyapi' 2>/dev/null || true)

if [[ -z "${API_KEY:-}" || "${API_KEY}" == "null" ]]; then
    # fallback: try the original place (if you replaced your stored key there)
    API_KEY=$(secret-tool lookup 'application' 'illogical-impulse' | jq -r '.apiKeys.gemini' 2>/dev/null || true)
fi

if [[ -z "${API_KEY:-}" || "${API_KEY}" == "null" ]]; then
    echo "ERROR: ProxyAPI key not found. Store it in secret-tool or set PROXYAPI_KEY env var."
    exit 2
fi

# Allow overriding key via env var (convenience)
API_KEY="${PROXYAPI_KEY:-$API_KEY}"

# Notify start
notify-send "Translation started" "Translating to ${TARGET_LOCALE} using ProxyAPI..." -a "$NOTIFICATION_APP_NAME"

#
# ProxyAPI configuration (per docs):
# - Base host: https://api.proxyapi.ru
# - For Gemini: use /google/v1beta/models/<model>:generateContent
# - Authorization: Bearer <KEY>
# See: https://proxyapi.ru/docs/overview and https://proxyapi.ru/docs/gemini-text-generation
#
PROXY_API_HOST="${PROXY_API_HOST:-https://api.proxyapi.ru/google}"
REQUEST_URL="${PROXY_API_HOST%/}/v1beta/models/${MODEL}:generateContent"

# Perform request to ProxyAPI (use Bearer auth as recommended)
response=$(curl -sS \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${API_KEY}" \
    -X POST "$REQUEST_URL" \
    -d "$payload" \
    2> /dev/null || true)

# Basic validation & write output
translated_json=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null || true)

if [[ -z "${translated_json}" || "${translated_json}" == "null" ]]; then
    echo "ERROR: empty response from ProxyAPI. Raw response:"
    echo "$response" | jq -C '.' || echo "$response"
    notify-send "Translation failed" "ProxyAPI returned no valid translation. See terminal output." -a "$NOTIFICATION_APP_NAME"
    exit 3
fi

echo "$translated_json" > "${TRANSLATIONS_TARGET_DIR}/${TARGET_LOCALE}.json"

# Update UI locale in config
if [[ -f "$SHELL_CONFIG_FILE" ]]; then
    jq --arg locale "$TARGET_LOCALE" '.language.ui = $locale' "$SHELL_CONFIG_FILE" > "${SHELL_CONFIG_FILE}.tmp" && mv "${SHELL_CONFIG_FILE}.tmp" "$SHELL_CONFIG_FILE"
fi

notify-send "Translation complete" "Saved to ${TRANSLATIONS_TARGET_DIR}/${TARGET_LOCALE}.json" -a "$NOTIFICATION_APP_NAME"
