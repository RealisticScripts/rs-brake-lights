# RS Brake Lights

A realistic vehicle brake light script for FiveM.

## Features

- Works across all GTA V vehicle classes without class filtering
- Forces brake lights while the local driver is slowing or stopped under the configured threshold
- Optional park effect that turns the brake lights off after the vehicle remains stopped for a random time window
- Detailed debug logging for both client and server when `Config.debug` is enabled
- Unified GitHub release version check on resource start

## Requirements

- FiveM server using `fx_version 'cerulean'`
- `lua54 'yes'`

## Installation

1. Place `rs-brake-lights` in your server's resources folder.
2. Add `ensure rs-brake-lights` to your `server.cfg`.
3. Adjust `config.lua` only if you want different timing or threshold behavior.
4. Restart the resource or server.

## Configuration

### `Config.debug`
Enables detailed client/server console output for troubleshooting.

### `Config.enableParkEffect`
When enabled, the brake lights switch off after the vehicle remains stopped long enough to simulate being put in park.

### `Config.parkTimerMin`
Minimum park-effect delay in seconds.

### `Config.parkTimerMax`
Maximum park-effect delay in seconds.

### `Config.brakeLightThreshold`
Speed threshold in MPH used to keep brake lights on while slowing or stopped.

## File Structure

```text
rs-brake-lights/
├── client.lua
├── config.lua
├── fxmanifest.lua
├── LICENSE
├── README.md
└── server.lua
```

## License

Released under the MIT License. See `LICENSE` for full text.
