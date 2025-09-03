# Arch & CachyOS Fixes and Customizations

Personal repo of configs and scripts for Arch/CachyOS—mostly small fixes, sometimes personal tweaks.

## What’s inside

### Elgato Products
`/stream_deck/wave_xlr` – Shell scripts for audio routing on PipeWire/WirePlumber (can be used with an Elgato Stream Deck).  

- `toggle-audio.sh` Script that toggles/set default sinks/sources via `wpctl`.
- `toggle-mute.sh` Script that toggles hardware and software mute (and keeps them in sync) on an Elgato Wave XLR or Elgato Wave:X microphone
- `toggle-hardware-mute.sh` Script that toggles hardware mute on an Elgato Wave XLR or Elgato Wave:X microphone
- `toggle=software-mute.sh` Script that toggles software mute on an Elgato Wave XLR or Elgato Wave:X microphone

> Tip: make scripts executable (`chmod +x *.sh`) and call them from your Stream Deck profile or any hotkey runner.

`/stream_deck/icons` – High quality PNG icons for use on an Elgato Stream Deck

## Requirements
- Arch or derivative distribution such as CachyOS
- PipeWire + WirePlumber (`wpctl` available)
- OpenDeck or another open source Stream Deck software

## Usage (example)
    # from repo root
    cd stream_deck
    ./toggle-audio.sh    # toggles default playback/capture between Wave XLR's headphones and another audio device you’ve configured

Use OpenDeck's "Run Command" to a button to flip audio routes on demand.

## Notes
- Designed for KDE/Wayland but should be DE-agnostic.
- Scripts are minimal; read the top comments/vars in each file to customize targets.

## Contributing
PRs/issues welcome for small fixes, extra scripts, or notes.
