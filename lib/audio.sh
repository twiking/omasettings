# Part of OmaSettings. Sourced by bin/omasettings; not run on its own.
#
# Audio devices through PulseAudio's protocol (pipewire-pulse answers it), the
# same interface the bar's audio widget uses. Nothing here is stored: the
# server owns the defaults, the volumes and the mutes.

# Monitor sources are loopbacks of an output, not microphones; showing them
# under Input would offer to record the speakers.
audio_devices() {
  local kind=$1
  pactl -f json list "$kind" 2>/dev/null | jq -c --arg kind "$kind" '
    [ .[]
      | select($kind != "sources" or (.name | test("\\.monitor$") | not))
      | { name: .name,
          description: (.description // .name),
          muted: (.mute == true),
          volume: (( .volume | to_entries | map(.value.value_percent | rtrimstr("%") | tonumber) | add / length ) | round) } ]'
}

audio_state() {
  command -v pactl >/dev/null 2>&1 || { echo '{"available": false}'; return; }

  jq -cn --argjson outputs "$(audio_devices sinks)" \
    --argjson inputs "$(audio_devices sources)" \
    --arg defaultOutput "$(pactl get-default-sink 2>/dev/null)" \
    --arg defaultInput "$(pactl get-default-source 2>/dev/null)" \
    '{ available: true,
       outputs: [$outputs[] | . + { default: (.name == $defaultOutput) }],
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
