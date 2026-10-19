#!/bin/sh
# One line for the network widget: <wired|wifi|none> <device> <system proxy 0|1> <tailscale off|on|exit>
PATH="/opt/homebrew/bin:$PATH"

# A cable wins over Wi-Fi ("wired" sorts after "wifi", so sort -r puts it first).
link=$(networksetup -listallhardwareports \
  | awk '/^Hardware Port:/{wifi=($3=="Wi-Fi")} /^Device:/{print (wifi?"wifi":"wired"), $2}' \
  | while read -r kind dev; do
      case "$(ipconfig getifaddr "$dev")" in (""|169.254.*) ;; (*) echo "$kind $dev" ;; esac
    done | sort -r | head -n1)

# Proxyman (and any other debugging proxy) works by switching on the system proxy.
proxy=$(scutil --proxy | awk '/(HTTP|HTTPS|SOCKS|ProxyAutoConfig)Enable : 1/{f=1} END{print f+0}')

ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale
tailscale=off
if [ -x "$ts" ]; then
  tailscale=$("$ts" status --json --peers=false 2>/dev/null \
    | jq -r 'if .BackendState != "Running" then "off" elif .ExitNodeStatus then "exit" else "on" end' 2>/dev/null)
fi

echo "${link:-none en0} $proxy ${tailscale:-off}"
