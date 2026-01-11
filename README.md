# dotfiles

## Setup

```zsh
./setup.sh
```

## VSCode Configuration

### [settings.json](vscode/settings.json)

CommandPalette -> "Open User Settings (JSON)", copy over.

### [keybindings.json](vscode/keybindings.json)

CommandPalette -> "Open Keyboard Shortcuts (JSON)", copy over.

### [extensions.txt](vscode/extensions.txt)

To regenerate:

```zsh
code --list-extensions > vscode/extensions.txt
```

To install (run automatically by `setup.sh`):

```zsh
cat vscode/extensions.txt | xargs -L 1 -I {} code --install-extension {} --force
```

Replace `code` with `cursor` or `agy` or whatever VSCode fork you're using.
