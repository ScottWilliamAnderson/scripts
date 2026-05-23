# Start-Opencode 🤖

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%2B%20WSL2-blue.svg)](https://learn.microsoft.com/en-us/windows/wsl/)
[![OpenShell](https://img.shields.io/badge/NVIDIA-OpenShell-76b900.svg)](https://github.com/NVIDIA/OpenShell)
[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

One-command launcher for [opencode](https://opencode.ai) running inside a sandboxed [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell) environment in WSL, with phone access over Tailscale.

> Open laptop → `Start-Opencode <repo>` → coding in the browser, on phone too.

## 📌 Features

- 🧱 Per-project OpenShell sandbox (isolated FS, network policy enforced)
- 🔑 opencode web password stored DPAPI-encrypted under `%LOCALAPPDATA%` — never on the command line
- 📡 Auto port-forward from sandbox → Windows → Tailscale tailnet
- 📱 Phone access via Tailscale MagicDNS at `http://<your-wsl-tailnet-name>:4096` (the script prints both the MagicDNS URL and the raw Tailscale IP, so you have a fallback if MagicDNS isn't resolving on the phone)
- 🦙 Optional `-Llama` flag opens a policy hole to a local `llama-server` on the Windows host
- ♻️ Idempotent: re-run any time to resume; sandbox, forward and opencode are reused if already up
- 🧹 `-Recreate` to nuke and start fresh when an upload goes stale

## 🚀 Usage

```powershell
Start-Opencode <project> [-Port 4096] [-Llama] [-LlamaPort 8081]
                         [-NoBrowser] [-Recreate]
                         [-SrcRoot <path>] [-Distro <wsl-distro>]
```

### Parameters

| Parameter    | Type   | Default            | Description                                                                              |
| ------------ | ------ | ------------------ | ---------------------------------------------------------------------------------------- |
| `Project`    | string | *required*         | Folder name under `$SrcRoot` — also the sandbox name. `[A-Za-z0-9._-]+`.                |
| `Port`       | int    | `4096`             | Local port for the opencode web UI (1024-65535).                                         |
| `Llama`      | switch | off                | Allow the sandbox to reach a local `llama-server` on the Windows host's Tailscale IP.    |
| `LlamaPort`  | int    | `8081`             | Port `llama-server` is listening on.                                                     |
| `NoBrowser`  | switch | off                | Don't auto-open the browser to the web UI.                                               |
| `Recreate`   | switch | off                | Delete the existing sandbox and create a fresh one (re-uploads files).                   |
| `RotatePassword` | switch | off            | Re-prompt for the opencode web password, replace the openshell provider, restart `opencode web` so the new password takes effect immediately. |
| `SrcRoot`    | string | `$env:USERPROFILE\src` | Root directory containing your project folders.                                      |
| `Distro`     | string | `Ubuntu-24.04`     | WSL distro with OpenShell installed.                                                     |

### Examples

```powershell
# Daily use — resume or create the 'liftosaur' sandbox, open browser
Start-Opencode liftosaur

# Switch projects mid-day — second sandbox on a different port
Start-Opencode trvl -Port 4097

# Use a local llama.cpp model from inside the sandbox
Start-Opencode liftosaur -Llama
# (then in opencode, point a custom provider at http://<your-windows-tailscale-ip>:8081/v1)

# After a big upstream change, refresh the upload
Start-Opencode liftosaur -Recreate
```

## ⚙️ Requirements

### Windows side
- Windows 10/11 with WSL2
- PowerShell 5.1 or later
- [Tailscale for Windows](https://tailscale.com/download/windows) (free tier is fine), logged in

### WSL side (Ubuntu-24.04 or newer)
- glibc ≥ 2.38 — **Ubuntu 22.04 will NOT work**, OpenShell gateway needs 2.38+
- [NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell) installed (`curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh`)
- An `openrouter` provider configured: `openshell provider create --name openrouter --type generic --credential OPENROUTER_API_KEY=sk-or-...`
- [Tailscale in WSL](https://tailscale.com/kb/1018/install-debian-bookworm) (`curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`)

### Phone (optional, for remote access)
- Tailscale app installed and signed into the same tailnet
- "Use Tailscale DNS" enabled (so `g14-wsl` resolves)

## 🔍 Troubleshooting

| Symptom                                           | Likely cause / fix                                                                                                                          |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `Gateway not reachable`                           | OpenShell gateway service crashed. In WSL: `sudo systemctl --user -M root@ restart openshell-gateway`, then check `openshell status`.       |
| `provider failure` / `Missing provider`           | Make sure both `openrouter` and `opencode_web` exist: `wsl openshell provider list`. Recreate if missing.                                   |
| `CONNECT app.opencode.ai:443 not permitted`       | Policy step didn't apply. Re-run the script; the policy update is idempotent.                                                               |
| Browser hangs / nothing on `localhost:4096`       | Check the web log: `wsl openshell sandbox exec -n <project> --no-tty -- cat /tmp/opencode-web.log`. Common cause: opencode failed to start. |
| Login prompt won't accept password                | Username is literally `opencode` (not blank). Password is whatever you set on first run.                                                    |
| Phone can't reach `<your-wsl-name>:<port>`         | Ensure "Use Tailscale DNS" is on in the phone app. Use the raw IP fallback printed by the script (it's the WSL distro's Tailscale IP, *not* Windows's — the port forward binds in WSL). You can also get it directly with `wsl -- tailscale ip -4`. |
| `-Llama` works on Windows but not from sandbox    | `llama-server` must bind `--host 0.0.0.0`. Also check Windows firewall allows inbound on the llama port from the Tailscale interface.       |
| First upload took forever                         | `--upload` walks `.gitignore`. For a one-off, `-Recreate` will re-upload; for ongoing dev, prefer editing inside the sandbox via VS Code remote SSH. |

## 💡 Tips

- **Browse sandbox files from VS Code:** in a second WSL terminal run `openshell sandbox connect <project> --editor vscode`. VS Code opens with Remote-SSH into the sandbox.
- **Multiple projects at once:** each project gets its own sandbox; use a distinct `-Port` per concurrent project.
- **Phone bookmarks:** add the MagicDNS URL printed by the script (`http://<your-wsl-name>:4096`) and/or the raw Tailscale-IP fallback URL to your phone's home screen.
- **Stopping cleanly:** `wsl openshell sandbox exec -n <project> --no-tty -- pkill -f "opencode web"` then `wsl openshell forward stop <port> <project>`.
- **Rotating the web password:** `Start-Opencode <project> -RotatePassword` does it all in one shot — wipes the DPAPI file, drops & recreates the openshell provider, restarts opencode web so the new password takes effect immediately.

## 🔐 Security notes

- The opencode web password lives in a DPAPI-encrypted file scoped to your Windows user account — equivalent in strength to Windows Credential Manager entries.
- The sandbox is sealed by OpenShell's network policy. Outbound HTTPS only works to hosts explicitly allowlisted (this script adds `app.opencode.ai`, `api.opencode.ai`, and your llama-server IP if `-Llama`). OpenRouter is allowed via the `openrouter` provider's auto-policy.
- Tailscale only exposes the port to *your* tailnet devices, not the public internet.

## 📝 License

MIT © Scott Anderson 2026

---
*For more utilities, visit the main repository [here](../README.md)*
