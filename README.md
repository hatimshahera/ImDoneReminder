# ImDoneReminder

Version: 0.1.0

ImDoneReminder is a lightweight macOS menu bar app. When Codex, Claude Code, Cursor, or another local coding agent finishes a task or needs attention, it can show a flying banner across your screen.

I built this because I kept losing track of my coding agents. I would start Codex or Claude Code, switch tabs while it worked, end up on YouTube or doomscrolling, and then forget it was waiting for me to approve something or check the finished result.

I was inspired by [conniexu444/meeting-reminder](https://github.com/conniexu444/meeting-reminder), and wanted to make something similar for coding agents instead of meetings.

## Run

```bash
git clone https://github.com/hatimshahera/ImDoneReminder.git
cd ImDoneReminder
swift run ImDoneReminder
```

The setup window opens automatically. Use the setup pages inside the app to copy the right prompt/config for Codex, Claude Code, Cursor, or a generic CLI agent.

Close the settings window when you are done. The app keeps running from the menu bar icon. To stop it, use the menu bar icon and choose `Quit`.

## Requirements

- macOS 14 or newer
- Xcode or Xcode command line tools
- Python 3

## Manual Test

```bash
./scripts/imdone done --source codex --label "demo task"
./scripts/imdone permission --source claude --label "demo task" --detail "approval requested"
```

## Notes

- Settings save automatically.
- The app must be running for flying banners.
- Events are sent locally to `127.0.0.1`; there is no backend or telemetry.
- Hosted/cloud-only coding tools cannot trigger the banner unless they can run a command on your Mac.

## Support

I would turn this into a proper downloadable app if it were not for a lack of funds, haha. If you like it and want to support that, you can do it here:

https://buymeacoffee.com/hatimshahera

Windows support coming soon.
