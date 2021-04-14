# Load Composer tools
export PATH="$HOME/.composer/vendor/bin:$PATH"

# Load Node global installed binaries
export PATH="$HOME/.node/bin:$PATH"

# Use project specific binaries before global ones
export PATH="node_modules/.bin:vendor/bin:$PATH"

# Add android studio
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
export PATH="$HOME/Library/Android/sdk/emulator:$HOME/Library/Android/sdk/tools:$PATH"

# Add Golang
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOROOT/bin

# Make sure coreutils are loaded before system commands
# I've disabled this for now because I only use "ls" which is
# referenced in my aliases.zsh file directly.
#export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
