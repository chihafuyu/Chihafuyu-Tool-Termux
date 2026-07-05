#!/usr/bin/env bash
# Chihafuyu Tool Termux Installer
# This script securely downloads and sets up the main patching utility in Termux.
# Author: chihafuyu | License: MIT 2026

# [DEBUG] Strict Execution Mode:
# errexit: Exits immediately if any command returns a non-zero status.
# pipefail: Catches errors inside pipelines (e.g., if curl fails but is piped to something else).
# nounset: Throws an error if an uninitialized variable is used.
# CDPATH: Unset to prevent unexpected directory jumps if the environment is poisoned.
set -o errexit
set -o pipefail
set -o nounset
unset CDPATH

echo -e "\e[36m[*] Initializing Chihafuyu Tool installation...\e[0m"

# 1. Navigate to the Termux home directory safely to prevent permission issues
# [DEBUG] Always explicitly quote "$HOME". Termux relies strictly on its internal app data directory 
# due to Android 11+ SELinux and Scoped Storage restrictions.
cd "$HOME" || { 
    echo -e "\e[31m[!] Failed to access the home directory. Aborting.\e[0m"
    exit 1
}

# 2. Pre-flight dependency check
# [DEBUG] Checking for 'curl' silently. If it's missing, the script halts before attempting downloads.
if ! command -v curl >/dev/null 2>&1; then
    echo -e "\e[31m[!] Error: 'curl' is not installed. Please run 'pkg install curl' first.\e[0m"
    exit 1
fi

# 3. Securely download the main script from the GitHub repository
echo -e "\e[90m[*] Downloading the main script from GitHub...\e[0m"
# [DEBUG] Download flags:
# -f (fail): Crucial! Forces curl to throw an error on 404/500 HTTP responses instead of downloading a dummy HTML error page.
# -S (show-error): Shows the error message if it fails.
# -L (location): Follows redirects automatically.
curl -fSL "https://raw.githubusercontent.com/chihafuyu/Chihafuyu-Tool-Termux/dev/chihafuyu-tool.sh" -o chihafuyu-tool.sh

# Verify if the download was completely successful and file exists
if [ ! -f "chihafuyu-tool.sh" ]; then
    echo -e "\e[31m[!] Error: Failed to download the main script. Please check your internet connection or URL.\e[0m"
    exit 1
fi

# [DEBUG] CRLF Stripping: Fixes the infamous "command not found" or syntax errors caused by 
# executing scripts that were written/edited in a Windows environment (CRLF instead of LF) before being pushed to Git.
sed -i 's/\r$//' chihafuyu-tool.sh

# 4. Grant execution permissions to the downloaded script
echo -e "\e[90m[*] Applying execution permissions...\e[0m"
chmod +x chihafuyu-tool.sh

# 5. Finish the installation process and launch the tool
echo -e "\e[32m[✓] Installation completed successfully!\e[0m"
echo -e "\e[33m[*] Starting Chihafuyu Tool...\e[0m"
sleep 1

# [DEBUG] 'exec' completely replaces the current installer process with the main script.
# This prevents the installer from hanging idly in the background and saves Termux memory by reusing the exact same PID.
exec "$HOME/chihafuyu-tool.sh"