# Color Clash

Roblox game, synced into Studio with [Rojo](https://rojo.space).

## Setup

```bash
rokit install
rojo serve
```

Then in Roblox Studio open the Rojo plugin and click **Connect** (default `localhost:34872`).

## Layout

| Folder        | Syncs to                                   |
|---------------|--------------------------------------------|
| `src/server`  | `ServerScriptService.Server`               |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client`|
| `src/shared`  | `ReplicatedStorage.Shared`                 |

Scripts: `*.server.luau` → Script, `*.client.luau` → LocalScript, `*.luau` → ModuleScript.
Workspace, Lighting, etc. are not managed by Rojo — build those in Studio.
