# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.
#
# Audio devices through PulseAudio's protocol (pipewire-pulse answers it), the
# same interface the bar's audio widget uses. Nothing here is stored: the
# server owns the defaults, the volumes and the mutes.

# Which sinks are worth offering. An HDMI output with no cable in it still
# exists in the graph, and a speaker tuning puts a virtual sink in front of the
# real speakers — picking the physical one would only bypass the tuning. The
# bar's audio widget asks omarchy-audio-sink-availability about both; so does
# this, or the two lists disagree about what you own.
audio_availability() {
  omarchy-audio-sink-availability 2>/dev/null \
    | jq -R -s -c 'split("\n")
      | map(select(length > 0) | split("\t") | { key: .[0], value: (.[1] != "0") })
      | from_entries'
}

# Monitor sources are loopbacks of an output, not microphones; showing them
# under Input would offer to record the speakers.
audio_devices() {
  local kind=$1
  pactl -f json list "$kind" 2>/dev/null | jq -c --arg kind "$kind" '
    # The same label the widget shows: the short nickname a device gives
    # itself, not the sentence-long description PulseAudio assembles.
    def short_name(device):
      (device.properties["node.nick"] //
       device.properties["device.profile.description"] //
       device.description // device.name)
      | gsub("^sof-soundwire\\s+"; "")
      | gsub("(?i)^built-?in audio\\s+"; "")
      | sub("\\s+Output$"; "")
      | sub("\\s+Input$"; "")
      | gsub("Microphones"; "Microphone");

    [ .[]
      | select($kind != "sources" or (.name | test("\\.monitor$") | not))
      # Quickshell publishes a node of its own; it is not a microphone.
      | select(.name != "quickshell")
      | { name: .name,
          description: short_name(.),
          icon: (.properties["device.icon-name"] // ""),
          muted: (.mute == true),
          volume: (( .volume | to_entries | map(.value.value_percent | rtrimstr("%") | tonumber) | add / length ) | round) } ]'
}

audio_state() {
  command -v pactl >/dev/null 2>&1 || { echo '{"available": false}'; return; }

  jq -cn --argjson outputs "$(audio_devices sinks)" \
    --argjson inputs "$(audio_devices sources)" \
    --argjson availability "$(audio_availability)" \
    --arg defaultOutput "$(pactl get-default-sink 2>/dev/null)" \
    --arg defaultInput "$(pactl get-default-source 2>/dev/null)" \
    '{ available: true,
       outputs: [$outputs[]
         | . + { default: (.name == $defaultOutput) }
         # Whatever is playing right now stays listed even if it reports
         # itself unavailable, so the current output is never missing.
         | select(.default or ($availability[.name] != false))],
       inputs: [$inputs[] | . + { default: (.name == $defaultInput) }] }'
}

# Switching the default alone leaves whatever is already playing on the old
# device, which reads as the setting not working. Move the streams too, the
# way every audio panel does.
audio_move_streams() {
  local kind=$1 target=$2 stream
  local list_kind=sink-inputs move=move-sink-input
  [[ $kind == input ]] && { list_kind=source-outputs; move=move-source-output; }

  while read -r stream _; do
    [[ -n $stream ]] || continue
    pactl "$move" "$stream" "$target" >/dev/null 2>&1 || true
  done < <(pactl list short "$list_kind" 2>/dev/null)
}

audio_cmd() {
  local action=${1:-} kind=${2:-} value=${3:-}
  command -v pactl >/dev/null 2>&1 || die "PulseAudio is not available"
  [[ $action == state ]] || [[ $kind == output || $kind == input ]] || die "expected output or input"

  local device=sink
  [[ $kind == input ]] && device=source

  case $action in
    state) audio_state ;;
    default)
      [[ -n $value ]] || die "no device given"
      pactl "set-default-$device" "$value" >/dev/null 2>&1 || die "could not switch to that device"
      audio_move_streams "$kind" "$value" ;;
    volume)
      [[ $value =~ ^[0-9]+$ ]] || die "'$value' is not a percentage"
      ((value <= 150)) || die "that is louder than this will go"
      pactl "set-$device-volume" @DEFAULT_${device^^}@ "${value}%" >/dev/null 2>&1 \
        || die "could not set the volume" ;;
    mute)
      case $value in
        on|off|toggle)
          local flag=$value
          [[ $value == on ]] && flag=1
          [[ $value == off ]] && flag=0
          pactl "set-$device-mute" @DEFAULT_${device^^}@ "$flag" >/dev/null 2>&1 \
            || die "could not change the mute" ;;
        *) die "expected on, off or toggle" ;;
      esac ;;
    *) die "unknown audio action '$action'" ;;
  esac
}
