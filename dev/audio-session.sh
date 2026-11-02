#!/usr/bin/env bash
# Private virtual audio nodes only. Never connects to the user's audio daemon.
set -euo pipefail
cd /project
mkdir -p artifacts/development
pipewire > artifacts/development/pipewire.txt 2>&1 &
audio_pid=$!
manager_pid=
trap 'kill "$audio_pid" ${manager_pid:+"$manager_pid"} 2>/dev/null || true' EXIT
for ((i=0;i<100;i++)); do [[ -S $XDG_RUNTIME_DIR/pipewire-0 ]] && break; sleep .05; done
wireplumber > artifacts/development/wireplumber.txt 2>&1 &
manager_pid=$!
sleep .5
timeout 5s pw-cli create-node adapter '{ factory.name = support.null-audio-sink node.name = illuminated-test-sink node.description = "Illuminated virtual sink" media.class = Audio/Sink object.linger = true audio.position = [ FL FR ] }'
timeout 5s pw-cli create-node adapter '{ factory.name = support.null-audio-sink node.name = illuminated-test-sink-two node.description = "Illuminated virtual sink two" media.class = Audio/Sink object.linger = true audio.position = [ FL FR ] }'
timeout 5s pw-cli create-node adapter '{ factory.name = support.null-audio-sink node.name = illuminated-test-source node.description = "Illuminated virtual source" media.class = Audio/Source object.linger = true audio.position = [ FL FR ] }'
sleep 1
timeout 5s wpctl status > artifacts/development/pipewire-status.txt
export ILLUMINATED_PIPEWIRE_PID=$audio_pid ILLUMINATED_WIREPLUMBER_PID=$manager_pid
"$@"
