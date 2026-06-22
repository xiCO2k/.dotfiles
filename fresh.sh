#!/bin/sh

echo "Setting up your Mac..."

# Check for Oh My Zsh and install if we don't have it
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no KEEP_ZSHRC=yes /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
fi

# Check for Homebrew and install if we don't have it
if test ! $(which brew); then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# Removes .zshrc from $HOME (if it exists) and symlinks the .zshrc file from the .dotfiles
rm -rf $HOME/.zshrc
ln -sw $HOME/.dotfiles/.zshrc $HOME/.zshrc

# Install the zsh-autosuggestions plugin (referenced in .zshrc). The plugins/
# folder is gitignored, so it must be cloned on a fresh machine. ZSH_CUSTOM
# points at the dotfiles dir, so oh-my-zsh looks for it under ./plugins.
if [ ! -d "$HOME/.dotfiles/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.dotfiles/plugins/zsh-autosuggestions"
fi

# Install Rosetta 2 on Apple Silicon (needed by some Intel-only App Store apps/casks)
if [ "$(uname -m)" = "arm64" ]; then
  softwareupdate --install-rosetta --agree-to-license || true
fi

# Update Homebrew recipes
brew update

# Skip the post-install cleanup step, which can fail on a stale/corrupted
# download cache and report a false "Installing <pkg> has failed!".
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Install all our dependencies with bundle (See Brewfile)
brew bundle --file ./Brewfile

# Install little-snitch separately so a transient DMG download failure doesn't
# abort the whole bundle. Ignore failures here.
brew install --cask little-snitch || echo "little-snitch install failed (download may be temporarily unavailable); install it manually later."

# Set default MySQL root password and auth type (only if mysql is installed)
if command -v mysql >/dev/null 2>&1; then
  brew services start mysql || true
  # Wait for the server to accept connections before altering the root user.
  for _ in $(seq 1 30); do
    mysqladmin ping --silent 2>/dev/null && break
    sleep 1
  done
  # Prefer the legacy mysql_native_password plugin; fall back to the default
  # auth plugin on MySQL 8.4+/9.x where it is disabled/removed by default.
  mysql -u root -e "ALTER USER root@localhost IDENTIFIED WITH mysql_native_password BY 'password'; FLUSH PRIVILEGES;" 2>/dev/null \
    || mysql -u root -e "ALTER USER root@localhost IDENTIFIED BY 'password'; FLUSH PRIVILEGES;" \
    || true
fi

# Create a projects directory
mkdir -p $HOME/code

# Symlink the Mackup config file to the home directory
ln -sf $HOME/.dotfiles/.mackup.cfg $HOME/.mackup.cfg

# Symlink Ghostty config
mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
ln -sf $HOME/.dotfiles/ghostty.config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

# Symlink Ghostty custom theme
mkdir -p "$HOME/.config/ghostty/themes"
ln -sf $HOME/.dotfiles/ayu-mirage-custom.theme "$HOME/.config/ghostty/themes/ayu-mirage-custom"

# Configure gh CLI aliases (only if gh is installed)
if command -v gh >/dev/null 2>&1; then
  gh alias set --clobber open 'browse'
  gh alias set --clobber desktop '!open -a "GitHub Desktop" "$(git rev-parse --show-toplevel)"'
fi

# Set macOS preferences - we will run this last because this will reload the shell
source ./.macos
