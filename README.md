# grammarfix

A system-wide hotkey for macOS that fixes spelling, grammar, and punctuation in whatever you're typing, using Apple's **on-device** language model. Nothing leaves your Mac.

Press **⌃⌥⌘G** (Control + Option + Command + G) in Slack, Claude, a browser, or almost any other app, and the text is corrected in place.

## How it works

The project has two parts:

- **`grammarfix.swift`** is a small command-line tool. It takes text, sends it to Apple's on-device model through the [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels), and prints the corrected version.
- **`init.lua`** is a [Hammerspoon](https://www.hammerspoon.org) script that provides the hotkey.

When you press the hotkey, the script copies your selected text. In chat-style apps, it selects the whole message box if you haven't selected anything. It passes that text to `grammarfix`, pastes the result back over the original, and then restores whatever was on your clipboard before.

## Requirements

- A Mac with Apple Silicon (M1 or newer).
- macOS 26 (Tahoe) or later.
- Apple Intelligence turned on. The model must have finished downloading.
- Xcode command-line tools (Swift 6.2 or later), or the full Xcode 26.
- [Hammerspoon](https://www.hammerspoon.org).

## Repository layout

```
grammarfix/
├── grammarfix.swift   # on-device proofreading CLI
├── init.lua           # Hammerspoon hotkey script
└── README.md
```

The compiled `grammarfix` binary is built locally and shouldn't be committed. Add it to `.gitignore`:

```
grammarfix
```

## Setup

### 1. Turn on Apple Intelligence

Go to **System Settings → Apple Intelligence & Siri** and switch it on. On first use, macOS downloads the model in the background. Wait until that page no longer shows a download in progress.

### 2. Install the developer tools

```
xcode-select --install
swift --version   # should report Swift 6.2 or later
```

### 3. Clone the repo

The Hammerspoon script expects the project at `~/Projects/grammarfix`. If you clone it somewhere else, see [Configuration](#configuration).

```
mkdir -p ~/Projects
git clone <your-repo-url> ~/Projects/grammarfix
cd ~/Projects/grammarfix
```

### 4. Compile the tool

```
swiftc -O grammarfix.swift -o grammarfix
```

This creates the `grammarfix` executable in the project folder. Don't leave out `-o`; without it, `swiftc` treats `grammarfix` as a second source file and the link fails.

### 5. Test it

```
echo "teh meeting is moved too thursday, can you let everone know?" | ./grammarfix
```

You should get back the corrected sentence, and not an answer to the question. The first run takes a few seconds while the model loads; after that it's faster.

### 6. Install Hammerspoon

```
brew install --cask hammerspoon
```

Or download it from [hammerspoon.org](https://www.hammerspoon.org).

Open Hammerspoon and grant it **Accessibility** permission in **System Settings → Privacy & Security → Accessibility**. It needs this to send keystrokes to other apps. In Hammerspoon's preferences, also turn on **Launch Hammerspoon at login**.

### 7. Link the Hammerspoon script

Link the script from the repo, rather than copying it, so that `git pull` updates it automatically:

```
mkdir -p ~/.hammerspoon
ln -sf ~/Projects/grammarfix/init.lua ~/.hammerspoon/init.lua
```

If you already have a Hammerspoon config you want to keep, don't link over it. Instead, add this line to your existing `~/.hammerspoon/init.lua`:

```lua
dofile(os.getenv("HOME") .. "/Projects/grammarfix/init.lua")
```

### 8. Reload Hammerspoon

Click the Hammerspoon menu bar icon and choose **Reload Config**. You should see "Grammar fixer (on-device) loaded". If you see "grammarfix not found" instead, check that step 4 created `~/Projects/grammarfix/grammarfix`.

### 9. Check that it runs entirely on-device (optional)

Turn off Wi-Fi and press the hotkey. It should still work.

## Usage

| Where | What to do |
|---|---|
| Chat apps and browsers (Slack, Claude, Teams, Webex, Messages, Chrome, Safari, Edge, Arc, Firefox) | Click into the text box and press **⌃⌥⌘G**. With nothing selected, the whole message box is corrected. With text selected, only that text is corrected. |
| Any other app | Select the text first, then press **⌃⌥⌘G**. |
| Code editors and terminals | Disabled. |

A short status message shows what happened: **Correcting…**, **Fixed ✓**, **No changes needed ✓**, or an error message.

The script deliberately limits automatic selection to chat-style apps. In editors like Word, Notes, or Mail, ⌘A selects the entire document, and pasting the result over it would replace the whole thing and strip its formatting. Code editors and terminals are disabled because they often copy the whole current line when nothing is selected, which would cause the script to paste a duplicate line.

## Configuration

All settings are at the top of `init.lua`. Reload Hammerspoon after changing any of them.

| Setting | Purpose |
|---|---|
| `GRAMMARFIX` | Path to the compiled tool. Change this if you cloned the repo somewhere other than `~/Projects/grammarfix`. |
| `HOTKEY_MODS`, `HOTKEY_KEY` | The hotkey. The default is `{"ctrl", "alt", "cmd"}` plus `"G"`. |
| `MAX_CHARS` | Longest text the script will process (default 5000). Longer text is beyond what the on-device model handles well, and usually means a whole document was selected by accident. |
| `SELECT_ALL_APPS` | Apps where the script auto-selects the text box if nothing is selected. |
| `BLOCKED_APPS` | Apps where the hotkey is disabled. JetBrains IDEs are also blocked automatically. |

To find an app's bundle ID so you can add it to either list, run this, using the app's name as it appears in your Applications folder:

```
osascript -e 'id of app "Claude"'
```

### Adjusting the proofreading behavior

The model's instructions are the `instructions` string at the top of `grammarfix.swift`. If the corrections are too aggressive or too light, edit that string, then recompile:

```
cd ~/Projects/grammarfix
swiftc -O grammarfix.swift -o grammarfix
```

You don't need to reload Hammerspoon after recompiling; the tool is run fresh on every hotkey press.

## Setting up on a new Mac

1. Turn on Apple Intelligence (step 1).
2. Install the developer tools (step 2).
3. Clone the repo to `~/Projects/grammarfix` (step 3).
4. Compile the tool (step 4).
5. Install Hammerspoon and grant it Accessibility permission (step 6).
6. Link the script and reload Hammerspoon (steps 7 and 8).

## Troubleshooting

| Problem | Fix |
|---|---|
| `no such module 'FoundationModels'` when compiling | Your command-line tools don't include the macOS 26 SDK. Install Xcode 26 or later from the App Store, run `sudo xcode-select -s /Applications/Xcode.app`, and compile again. |
| `link command failed` / `no such file or directory: 'grammarfix'` | You left out `-o` in the compile command. Use `swiftc -O grammarfix.swift -o grammarfix`. |
| Deprecation warning or error about `GenerationOptions` | Apple has renamed parameters on this initializer between SDK releases. Use whatever name the compiler suggests (the current name is `samplingMode:`), or remove the `options:` argument entirely. |
| "Turn on Apple Intelligence" or "still downloading" | Check System Settings → Apple Intelligence & Siri, and wait for the model download to finish. |
| A model error on certain messages | Apple's model has built-in content filters that occasionally refuse harmless text. Correct that message by hand. |
| The hotkey does nothing | Make sure Hammerspoon has Accessibility permission and is running, and that no other app uses the same hotkey. |
| "select text first" in a chat app | That app isn't in `SELECT_ALL_APPS`. Add its bundle ID and reload Hammerspoon. |
| Nothing happens in a browser | Click into the text box before pressing the hotkey. If the page itself has focus, ⌘A selects the page, and pasting into it does nothing. |
| A long paste in Claude becomes an attachment | Claude can convert long pastes into a "pasted text" attachment. Correct a smaller section at a time. |
| You switched apps while it was working | The corrected text is left on your clipboard. Paste it manually. |

## Limitations

- The on-device model has a small context window. The tool is meant for message-length text, not long documents.
- Rich-text formatting applied with an app's toolbar can be lost, because the text goes through the clipboard as plain text. Markup you type yourself, like Markdown or Slack's `*bold*`, is preserved.
- The model is small, about 3 billion parameters. It occasionally misses errors or tweaks casual phrasing. Tightening the instructions in `grammarfix.swift` usually helps.
