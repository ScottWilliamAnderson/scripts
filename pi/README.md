# Pi setup

Personal config for [Pi](https://pi.dev), kept on `backup/pi-setup`.
Credentials, sessions, caches and installed packages aren't included.

To restore, close Pi and copy the contents of `agent/` into `~/.pi/agent/`.
Then run `pi update --extensions` to install the packages listed in `settings.json`.

Local package changes can be overwritten by updates. Reapply them with:

```powershell
node "$env:USERPROFILE\.pi\agent\patches\pi-unmarked-paste.mjs"
node "$env:USERPROFILE\.pi\agent\patches\pi-extension-startup.mjs"
git -C "$env:USERPROFILE\.pi\agent\npm\node_modules\pi-fusion" apply "$PWD\pi\fusion.patch"
```

`fusion.patch` preserves the custom live-progress display. If a patch no longer applies, review it against the updated package.

The agent files are model presets, not fixed roles. The parent supplies the task.
See the native docs for [Herdr subagents](https://github.com/aliceisjustplaying/pi-herdr-subagents), [You Should Know](https://github.com/aliceisjustplaying/pi-you-should-know) and the [Durable SDK](https://github.com/earendil-works/pi/tree/main/packages/durable).
