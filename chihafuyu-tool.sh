#!/usr/bin/env bash
# Chihafuyu Tool - Termux Edition
# Utility to automate Android app patching natively on Termux
# Author: chihafuyu | License: MIT 2026

# ==============================================================================
# SELF-UPDATE MECHANISM
# ==============================================================================
if [[ "${1:-}" == "--update" || "${1:-}" == "--upgrade" ]]; then
    echo -e "\e[36m[*] Fetching the latest script from GitHub (dev branch)...\e[0m"
    
    TMP_FILE=$(mktemp)
    
    # [DEBUG] Security Audit: Ensure the temporary payload is wiped from memory even if the user sends SIGINT (Ctrl+C).
    trap 'rm -f "$TMP_FILE"' EXIT
    
    SCRIPT_URL="https://raw.githubusercontent.com/chihafuyu/Chihafuyu-Tool-Termux/dev/chihafuyu-tool.sh"
    
    if curl -sL "$SCRIPT_URL" -o "$TMP_FILE"; then
        if grep -q "#!/usr/bin/env bash" "$TMP_FILE" || grep -q "#!/bin/bash" "$TMP_FILE"; then
            sed -i 's/\r$//' "$TMP_FILE"
            cp "$TMP_FILE" "$HOME/chihafuyu-tool.sh"
            chmod +x "$HOME/chihafuyu-tool.sh"
            echo -e "\e[32m[✓] Update successful! You are now running the latest version.\e[0m"
            exit 0
        else
            echo -e "\e[31m[!] Update failed: The downloaded file appears to be invalid or corrupted.\e[0m"
            exit 1
        fi
    else
        echo -e "\e[31m[!] Update failed: Could not connect to GitHub. Check your internet connection.\e[0m"
        exit 1
    fi
fi

# ==============================================================================
# INTERNET CONNECTION CHECK
# ==============================================================================
if ! ping -c 1 www.google.com &> /dev/null; then
    echo -e "\e[31m[!] No internet connection detected.\e[0m"
    exit 1
fi

echo -e "\e[36m[SYSTEM] Checking Termux environment prerequisites...\e[0m"
export DEBIAN_FRONTEND=noninteractive

# [DEBUG] Auto-Healing: Safely terminate hanging package managers and release lock files. 
# Soft SIGTERM (-f) is used instead of SIGKILL (-9) to prevent dpkg database corruption.
pkill -f "apt" > /dev/null 2>&1 || true
pkill -f "apt-get" > /dev/null 2>&1 || true
pkill -f "dpkg" > /dev/null 2>&1 || true
rm -f "$PREFIX/var/lib/dpkg/lock"* > /dev/null 2>&1
rm -f "$PREFIX/var/cache/apt/archives/lock" > /dev/null 2>&1
rm -f "$PREFIX/var/lib/apt/lists/lock" > /dev/null 2>&1

dpkg --configure -a > /dev/null 2>&1
apt-get --fix-broken install -y -q > /dev/null 2>&1

# Resolve core dependencies
if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null || ! command -v whiptail &> /dev/null || ! command -v tput &> /dev/null; then 
    echo -e "\e[90m  [i] Updating and installing core packages...\e[0m"
    apt-get update -y -q > /dev/null 2>&1
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" < /dev/null
    apt-get install -y jq curl whiptail ncurses-utils < /dev/null
    echo -e "\e[32m  [✓] Essential packages installed.\e[0m"
fi 

# Verify JVM environment (JDK 21)
java_ver=""
if command -v java &> /dev/null; then
    java_ver=$(java -version 2>&1 | grep -oP '"(?:1\.)?\K(\d+)' | head -n 1)
fi

if [ -z "$java_ver" ] || [ "$java_ver" -lt 21 ]; then
    echo -e "\e[35m      Downloading OpenJDK 21 natively via Termux (~100MB+). DO NOT close Termux!\e[0m"
    dpkg --configure -a > /dev/null 2>&1
    apt-get install -y openjdk-21 < /dev/null
fi

# Create Global Executable Shortcut
BIN_PATH="$PREFIX/bin/chihafuyu"
if [ ! -f "$BIN_PATH" ]; then
    cat << 'EOF' > "$BIN_PATH"
#!/usr/bin/env bash
bash ~/chihafuyu-tool.sh "$@"
EOF
    chmod +x "$BIN_PATH"
    echo -e "\e[32m[SYSTEM] Shortcut created! You can now just type 'chihafuyu' in Termux to start the tool.\e[0m"
    sleep 2
fi

# ==============================================================================
# UI DIMENSION CALCULATOR (HARDWARE-ACCURATE)
# ==============================================================================
calc_size() {
    # [DEBUG] checkwinsize commands bash to re-evaluate LINES and COLUMNS dynamically.
    # Crucial for mobile environments where screen orientation changes mid-execution.
    shopt -s checkwinsize
    local size=$(stty size 2>/dev/null || echo "24 80")
    local term_h=$(echo $size | awk '{print $1}')
    local term_w=$(echo $size | awk '{print $2}')
    
    WT_H=$((term_h - 2))
    WT_W=$((term_w - 4))
    
    if [ "$WT_H" -gt 24 ]; then WT_H=24; fi
    if [ "$WT_W" -gt 80 ]; then WT_W=80; fi
    
    WT_M=$((WT_H - 8))
    if [ "$WT_M" -lt 2 ]; then WT_M=2; fi 
}

# Initialize isolated workspace in public internal storage
calc_size
if [ ! -d "$HOME/storage/downloads" ]; then
    whiptail --title "Storage Permission" --msgbox "Termux requires storage permission to save files in your Downloads folder.\n\nPlease tap 'Allow' on the upcoming popup." $WT_H $WT_W
    termux-setup-storage
    sleep 3
    
    # [DEBUG] Security Audit: Abort execution if the user refuses to grant storage permissions.
    # Scoped Storage on Android 11+ prevents falling back to unapproved directories.
    if [ ! -d "$HOME/storage/downloads" ]; then
        echo -e "\e[31m[!] Storage access not granted. Operations cannot continue. Exiting.\e[0m"
        exit 1
    fi
fi

BASE_DIR="$HOME/storage/downloads/Chihafuyu"
mkdir -p "$BASE_DIR/CLI"

# Global fetcher state
FETCHED_FILE=""

fetch_github_artifact() {
    local repo="$1"
    local track="$2"
    local target_dir="$3"
    local file_ext="$4"

    mkdir -p "$target_dir" >&2
    calc_size
    whiptail --title "Downloading Artifacts" --infobox "Checking $repo ($track)..." $WT_H $WT_W

    local api_url="https://api.github.com/repos/$repo/releases"
    local api_response=$(curl -s "$api_url")
    
    local resp_type=$(echo "$api_response" | jq -r 'type')
    if [ "$resp_type" == "object" ]; then
        local check_err=$(echo "$api_response" | jq -r '.message // empty')
        if [ -n "$check_err" ]; then
            calc_size
            whiptail --title "GitHub API Error" --msgbox "Error accessing repository:\n$repo\n\nGitHub says: $check_err" $WT_H $WT_W
            return 1
        fi
    fi

    local download_url=""
    local file_name=""

    if [ "$track" == "stable" ]; then
        local latest_response=$(curl -s "$api_url/latest")
        local latest_type=$(echo "$latest_response" | jq -r 'type')
        
        if [ "$latest_type" == "object" ]; then
            local check_latest_err=$(echo "$latest_response" | jq -r '.message // empty')
            if [ -n "$check_latest_err" ]; then
                calc_size
                whiptail --title "Release Error" --msgbox "Error getting stable release for:\n$repo\n\nGitHub says: $check_latest_err" $WT_H $WT_W
                return 1
            fi
        fi
        download_url=$(echo "$latest_response" | jq -r ".assets[] | select(.name | endswith(\"$file_ext\")) | .browser_download_url" | head -n 1)
        file_name=$(echo "$latest_response" | jq -r ".assets[] | select(.name | endswith(\"$file_ext\")) | .name" | head -n 1)
    else
        download_url=$(echo "$api_response" | jq -r ".[0].assets[] | select(.name | endswith(\"$file_ext\")) | .browser_download_url" | head -n 1)
        file_name=$(echo "$api_response" | jq -r ".[0].assets[] | select(.name | endswith(\"$file_ext\")) | .name" | head -n 1)
    fi

    if [ -z "$download_url" ] || [ "$download_url" == "null" ]; then
        calc_size
        whiptail --title "File Not Found" --msgbox "Failed to find '$file_ext' in the releases of:\n$repo ($track)." $WT_H $WT_W
        return 1
    fi

    local target_file="$target_dir/$file_name"
    if [ -f "$target_file" ]; then
        FETCHED_FILE="$target_file"
        return 0
    fi

    calc_size
    whiptail --title "Downloading Artifacts" --infobox "Downloading $file_name...\nPlease wait." $WT_H $WT_W
    curl -L -# -o "$target_file" "$download_url" >&2
    
    if [ $? -eq 0 ]; then
        FETCHED_FILE="$target_file"
        return 0
    else
        rm -f "$target_file"
        calc_size
        whiptail --title "Download Failed" --msgbox "Failed to download $file_name. Check connection." $WT_H $WT_W
        return 1
    fi
}

fetch_gitlab_artifact() {
    local project_id="$1"
    local target_dir="$2"
    local file_ext="$3"

    mkdir -p "$target_dir" >&2
    calc_size
    whiptail --title "Downloading Artifacts" --infobox "Checking GitLab repository:\n$project_id..." $WT_H $WT_W

    local api_url="https://gitlab.com/api/v4/projects/$project_id/releases"
    local api_response=$(curl -s "$api_url")

    local download_url=$(echo "$api_response" | jq -r ".[0].assets.links[] | select(.name | endswith(\"$file_ext\")) | .url" | head -n 1)
    local file_name=$(echo "$api_response" | jq -r ".[0].assets.links[] | select(.name | endswith(\"$file_ext\")) | .name" | head -n 1)

    if [ -z "$download_url" ] || [ "$download_url" == "null" ]; then
        calc_size
        whiptail --title "File Not Found" --msgbox "Failed to find '$file_ext' in GitLab repository: $project_id." $WT_H $WT_W
        return 1
    fi

    local target_file="$target_dir/$file_name"
    if [ -f "$target_file" ]; then
        FETCHED_FILE="$target_file"
        return 0
    fi

    calc_size
    whiptail --title "Downloading Artifacts" --infobox "Downloading $file_name...\nPlease wait." $WT_H $WT_W
    curl -L -# -o "$target_file" "$download_url" >&2
    
    if [ $? -eq 0 ]; then
        FETCHED_FILE="$target_file"
        return 0
    else
        rm -f "$target_file"
        return 1
    fi
}

invoke_patching() {
    calc_size
    local cliTrack=$(whiptail --title "CLI Environment" --menu "Select Morphe CLI Track:" $WT_H $WT_W $WT_M \
        "stable" "Recommended Release" \
        "dev" "Experimental Pre-release" 3>&1 1>&2 2>&3)
    if [ -z "$cliTrack" ]; then return; fi

    local cli_repo="MorpheApp/morphe-cli"
    fetch_github_artifact "$cli_repo" "$cliTrack" "$BASE_DIR/CLI" ".jar" || return
    local cliJar="$FETCHED_FILE"

    calc_size
    local patchesTrack=$(whiptail --title "Patches Environment" --menu "Select Ecosystem Patches Track:" $WT_H $WT_W $WT_M \
        "stable" "Recommended Release" \
        "dev" "Experimental Pre-release" 3>&1 1>&2 2>&3)
    if [ -z "$patchesTrack" ]; then return; fi

    calc_size
    local ecoChoice=$(whiptail --title "Target Ecosystem" --menu "Select Ecosystem(s):" $WT_H $WT_W $WT_M \
        "1" "Morphe (YouTube, YT Music, Reddit)" \
        "2" "Piko (X/Twitter, Instagram)" \
        "3" "hoo-dles (AdGuard, IbisPaint X, CamScanner, etc.)" \
        "4" "De-ReVanced (Google Photos, RAR)" \
        "5" "BholeyKaBhakt (Speedtest, Stellarium, PROTO, etc.)" \
        "6" "browzomje (Pinterest)" 3>&1 1>&2 2>&3)
    if [ -z "$ecoChoice" ]; then return; fi

    declare -A pkg_map name_map keyword_map
    local app_menu=()

    case "$ecoChoice" in
        1) 
            project_name="Morphe"; patch_repo="MorpheApp/morphe-patches"
            app_menu=("youtube" "YouTube (Rec: 20.51.39)" ON "ytmusic" "YT Music (Rec: 9.15.51)" OFF "reddit" "Reddit (Rec: 2026.14.0)" OFF)
            pkg_map["youtube"]="com.google.android.youtube"; name_map["youtube"]="YouTube"; keyword_map["youtube"]="youtube"
            pkg_map["ytmusic"]="com.google.android.apps.youtube.music"; name_map["ytmusic"]="YT_Music"; keyword_map["ytmusic"]="music"
            pkg_map["reddit"]="com.reddit.frontpage"; name_map["reddit"]="Reddit"; keyword_map["reddit"]="reddit"
            ;;
        2) 
            project_name="Piko"; patch_repo="crimera/piko"
            app_menu=("twitter" "X/Twitter (Rec: 12.2.0)" ON "instagram" "Instagram (Rec: 435.0.0.37.76)" OFF)
            pkg_map["twitter"]="com.twitter.android"; name_map["twitter"]="X_Twitter"; keyword_map["twitter"]="twitter\|x"
            pkg_map["instagram"]="com.instagram.android"; name_map["instagram"]="Instagram"; keyword_map["instagram"]="instagram\|ig"
            ;;
        3) 
            project_name="hoo-dles"; patch_repo="hoo-dles/morphe-patches"
            app_menu=("adguard" "AdGuard (Rec: 4.12.81)" ON "ibispaint" "IbisPaint X (Rec: 14.0.4)" OFF "wps" "WPS Office (Rec: 18.24)" OFF "camscanner" "CamScanner (Rec: 7.15.5)" OFF)
            pkg_map["adguard"]="com.adguard.android"; name_map["adguard"]="AdGuard"; keyword_map["adguard"]="adguard"
            pkg_map["ibispaint"]="jp.ne.ibis.ibispaintx.app"; name_map["ibispaint"]="IbisPaint_X"; keyword_map["ibispaint"]="ibis"
            pkg_map["wps"]="cn.wps.moffice_eng"; name_map["wps"]="WPS_Office"; keyword_map["wps"]="wps"
            pkg_map["camscanner"]="com.intsig.camscanner"; name_map["camscanner"]="CamScanner"; keyword_map["camscanner"]="camscanner"
            ;;
        4) 
            project_name="De-ReVanced"; patch_repo="RookieEnough/De-Vanced"
            app_menu=("photos" "Google Photos (Any)" ON "rar" "RAR (Any)" OFF)
            pkg_map["photos"]="com.google.android.apps.photos"; name_map["photos"]="Google_Photos"; keyword_map["photos"]="photos"
            pkg_map["rar"]="com.rarlab.rar"; name_map["rar"]="RAR"; keyword_map["rar"]="rar"
            ;;
        5) 
            project_name="BholeyKaBhakt"; patch_repo="BholeyKaBhakt/android-patches-xtra"
            app_menu=("speedtest" "Speedtest (Rec: 7.0.4)" ON "stellarium" "Stellarium (Rec: 1.16.3)" OFF "proto" "PROTO (Rec: 1.49.0)" OFF)
            pkg_map["speedtest"]="org.zwanoo.android.speedtest"; name_map["speedtest"]="Speedtest"; keyword_map["speedtest"]="speedtest"
            pkg_map["stellarium"]="com.noctuasoftware.stellarium_free"; name_map["stellarium"]="Stellarium"; keyword_map["stellarium"]="stellarium"
            pkg_map["proto"]="com.proto.circuitsimulator"; name_map["proto"]="PROTO"; keyword_map["proto"]="proto"
            ;;
        6) 
            project_name="browzomje"; patch_repo="browzomje/browzomje-patches"
            app_menu=("pinterest" "Pinterest (Rec: 14.24.0)" ON)
            pkg_map["pinterest"]="com.pinterest"; name_map["pinterest"]="Pinterest"; keyword_map["pinterest"]="pinterest"
            ;;
    esac

    workspace="$BASE_DIR/$project_name"
    mkdir -p "$workspace/Input" "$workspace/Output"

    calc_size
    local appChoices=$(whiptail --title "Target Applications" --checklist "Select the applications you want to patch (Use SPACE to check/uncheck):" $WT_H $WT_W $WT_M "${app_menu[@]}" 3>&1 1>&2 2>&3)
    if [ -z "$appChoices" ]; then return; fi
    
    appChoices=$(echo "$appChoices" | tr -d '"')

    fetch_github_artifact "$patch_repo" "$patchesTrack" "$workspace" ".mpp" || return
    local patchesFile="$FETCHED_FILE"

    local extraPatchFile=""
    if [ "$ecoChoice" -eq 2 ]; then
        fetch_gitlab_artifact "inotia00%2Fx-shim" "$workspace" ".mpp" || return
        extraPatchFile="$FETCHED_FILE"
    fi

    local valid_targets=()
    for tag in $appChoices; do
        local a_name="${name_map[$tag]}"
        local k_word="${keyword_map[$tag]}"
        local found_apk=""

        while true; do
            # [DEBUG] Escaping parenthesis \( \) is strictly required for grouping OR conditionals 
            # within a standard find -iregex string to prevent syntax failures.
            found_apk=$(find "$workspace/Input" -maxdepth 1 -type f -iregex ".*\(${k_word}\).*\.\(apk\|apkm\|xapk\|apks\)$" | head -n 1)
            if [ -n "$found_apk" ]; then
                break
            fi
            
            calc_size
            if whiptail --title "APK Not Found" --yesno "Missing APK file for $a_name!\n\nPlease download the APK and place it inside:\nDownloads/Chihafuyu/$project_name/Input/\n\nSelect 'Yes' to check the folder again, or 'No' to skip this app." $WT_H $WT_W; then
                continue
            else
                break
            fi
        done

        if [ -n "$found_apk" ]; then
            valid_targets+=("$tag|$found_apk")
        fi
    done

    if [ ${#valid_targets[@]} -eq 0 ]; then
        calc_size
        whiptail --title "Abort" --msgbox "No valid APKs were provided. Aborting workflow." $WT_H $WT_W
        return
    fi

    calc_size
    local archChoice=$(whiptail --title "Target Architecture" --menu "Select architecture for library stripping (--striplibs):" $WT_H $WT_W $WT_M \
        "1" "arm64-v8a (Modern 64-bit devices)" \
        "2" "armeabi-v7a (Older 32-bit devices)" \
        "3" "x86_64 (Emulators/PC)" \
        "4" "x86 (Old Emulators)" \
        "5" "Universal (Do not strip libraries)" 3>&1 1>&2 2>&3)
    
    if [ -z "$archChoice" ]; then return; fi
    local arch_flag=""
    case "$archChoice" in
        1) arch_flag="arm64-v8a" ;;
        2) arch_flag="armeabi-v7a" ;;
        3) arch_flag="x86_64" ;;
        4) arch_flag="x86" ;;
        5) arch_flag="" ;;
    esac

    calc_size
    whiptail --title "Generating Options" --infobox "Generating options.json for selected apps..." $WT_H $WT_W
    for target in "${valid_targets[@]}"; do
        local t_tag="${target%%|*}"
        local t_pkg="${pkg_map[$t_tag]}"
        local t_name="${name_map[$t_tag]}"
        local jsonFile="$workspace/${t_name}-options.json"

        local optArgs=("-jar" "$cliJar" "options-create" "--patches" "$patchesFile")
        if [ -n "$extraPatchFile" ]; then optArgs+=("--patches" "$extraPatchFile"); fi
        optArgs+=("--out" "$jsonFile" "--filter-package-name" "$t_pkg")

        java "${optArgs[@]}" >/dev/null 2>&1
    done

    calc_size
    whiptail --title "Configuration Ready" --msgbox "The options.json files have been successfully generated in:\nDownloads/Chihafuyu/$project_name/\n\n[ACTION REQUIRED]\nIf you want to enable/disable specific patches, open your File Manager now, edit the JSON files, and save them.\n\nPress OK when you are ready to begin patching." $WT_H $WT_W

    local useCustomKeystore=0
    local disableSigning=0
    
    calc_size
    if whiptail --title "Keystore Configuration" --yesno "Use a custom keystore?" $WT_H $WT_W; then
        useCustomKeystore=1
        
        calc_size
        local ksMethod=$(whiptail --title "Keystore Input Method" --menu "How do you want to provide your credentials?" $WT_H $WT_W $WT_M \
            "1" "Enter credentials manually" \
            "2" "Load from 'custom-keystore.txt'" 3>&1 1>&2 2>&3)

        if [ "$ksMethod" == "2" ]; then
            local ksConfigFile="$BASE_DIR/custom-keystore.txt"
            if [ ! -f "$ksConfigFile" ]; then
                echo -e "# Keystore configuration file\nKeystorePath=my-release-key.keystore\nKeystoreAlias=MyAlias\nKeystorePassword=my_password\nKeystoreEntryPassword=my_entry_password" > "$ksConfigFile"
                calc_size
                whiptail --title "Template Created" --msgbox "The 'custom-keystore.txt' file was not found.\n\nA template has been created at:\nDownloads/Chihafuyu/custom-keystore.txt\n\nPlease fill it out, place your .keystore file in the same folder, and run the tool again." $WT_H $WT_W
                return
            fi
            
            keystoreFile=$(grep -v '^#' "$ksConfigFile" | grep -i '^KeystorePath=' | cut -d'=' -f2- | tr -d '\r' | xargs)
            keystoreAlias=$(grep -v '^#' "$ksConfigFile" | grep -i '^KeystoreAlias=' | cut -d'=' -f2- | tr -d '\r' | xargs)
            plainPass=$(grep -v '^#' "$ksConfigFile" | grep -i '^KeystorePassword=' | cut -d'=' -f2- | tr -d '\r' | xargs)
            plainEntryPass=$(grep -v '^#' "$ksConfigFile" | grep -i '^KeystoreEntryPassword=' | cut -d'=' -f2- | tr -d '\r' | xargs)

            if [[ "$keystoreFile" != /* ]]; then
                keystoreFile="$BASE_DIR/$keystoreFile"
            fi
            
            if [ ! -f "$keystoreFile" ]; then
                calc_size
                whiptail --title "Error" --msgbox "Keystore file not found at:\n$keystoreFile" $WT_H $WT_W
                return
            fi
        else
            calc_size
            keystoreFile=$(whiptail --title "Keystore Path" --inputbox "Enter Keystore filename/path:" $WT_H $WT_W 3>&1 1>&2 2>&3)
            calc_size
            keystoreAlias=$(whiptail --title "Keystore Alias" --inputbox "Enter Alias:" $WT_H $WT_W 3>&1 1>&2 2>&3)
            calc_size
            plainPass=$(whiptail --title "Keystore Password" --passwordbox "Enter Password:" $WT_H $WT_W 3>&1 1>&2 2>&3)
            calc_size
            plainEntryPass=$(whiptail --title "Entry Password" --passwordbox "Enter Entry Password:" $WT_H $WT_W 3>&1 1>&2 2>&3)
        fi
    fi

    calc_size
    if whiptail --title "Signature Configuration" --yesno "Disable final APK signing? (--unsigned)" $WT_H $WT_W; then
        disableSigning=1
    fi

    heapSize="2G"
    sysRamKB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [ -n "$sysRamKB" ]; then
        sysRamGB=$((sysRamKB / 1024 / 1024))
        if [ "$sysRamGB" -ge 8 ]; then heapSize="4G"; elif [ "$sysRamGB" -ge 6 ]; then heapSize="3G"; fi
    fi

    clear
    echo -e "\e[36m==============================================\e[0m"
    echo -e "\e[36m          EXECUTING BATCH PATCHING            \e[0m"
    echo -e "\e[36m==============================================\e[0m"
    echo -e "\e[90m[i] Workspace: Downloads/Chihafuyu/$project_name\e[0m"
    echo -e "\e[90m[i] JVM Heap Allocated: -$heapSize\e[0m\n"

    local temp_log="$workspace/Output/temp_patch_log.txt"
    > "$temp_log"

    for target in "${valid_targets[@]}"; do
        local t_tag="${target%%|*}"
        local t_apk="${target#*|}"
        local t_name="${name_map[$t_tag]}"
        local jsonFile="$workspace/${t_name}-options.json"
        
        apkName=$(basename "$t_apk")
        
        # Dual-stream logging to prevent ANSI escape codes in the log file
        echo -e "\n\e[35m>>> PATCHING: $apkName <<<\e[0m"
        echo ">>> PATCHING: $apkName <<<" >> "$temp_log"
        
        outputApkAbs="$workspace/Output/Patched_${apkName%.*}.apk"
        
        baseArgs=("-Xmx$heapSize" "-jar" "$cliJar" "patch" "--patches" "$patchesFile")
        if [ -n "$extraPatchFile" ]; then baseArgs+=("--patches" "$extraPatchFile"); fi
        
        baseArgs+=("--options-file" "$jsonFile" "--out" "$outputApkAbs")
        
        if [ -n "$arch_flag" ]; then baseArgs+=("--striplibs" "$arch_flag"); fi

        if [ "$disableSigning" -eq 1 ]; then
            baseArgs+=("--unsigned")
        elif [ "$useCustomKeystore" -eq 1 ]; then
            baseArgs+=("--keystore" "$keystoreFile" "--keystore-entry-alias" "$keystoreAlias" "--keystore-password" "$plainPass" "--keystore-entry-password" "$plainEntryPass")
        fi
        
        baseArgs+=("$t_apk")
        
        java "${baseArgs[@]}" 2>&1 | tee -a "$temp_log"
        
        # [DEBUG] Using PIPESTATUS[0] because piping output to 'tee' masks the original Java process exit code.
        # This is functionally equivalent to checking $LASTEXITCODE in PowerShell.
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo -e "\e[31m[!] Patching FAILED\e[0m\n"
            echo "[!] Patching FAILED" >> "$temp_log"
        else
            echo -e "\e[32m[✓] Patching SUCCEEDED -> Downloads/Chihafuyu/$project_name/Output/\e[0m\n"
            echo "[✓] Patching SUCCEEDED -> Downloads/Chihafuyu/$project_name/Output/" >> "$temp_log"
        fi
    done

    plainPass=""; plainEntryPass=""
    echo -e "\e[32m[SUCCESS] Batch operations concluded.\e[0m"
    echo "[SUCCESS] Batch operations concluded." >> "$temp_log"
    
    calc_size
    if whiptail --title "Export Logs" --yesno "Patching sequence complete.\n\nDo you want to export the patching logs to the Output folder?" $WT_H $WT_W; then
        local log_name="$workspace/Output/PatchLog_$(date +%Y%m%d_%H%M%S).txt"
        mv "$temp_log" "$log_name"
        echo -e "\e[90m[i] Logs exported to $log_name\e[0m"
    else
        rm -f "$temp_log"
    fi

    read -p "Press Enter to return to the Main Menu..."
}

while true; do
    calc_size
    mainChoice=$(whiptail --title "CHIHAFUYU TOOL" --menu "What do you want to do?" $WT_H $WT_W $WT_M \
        "1" "Patch apps" \
        "X" "Close" 3>&1 1>&2 2>&3)
    
    case "${mainChoice,,}" in
        1) invoke_patching ;;
        x|"")
            clear
            echo -e "\e[36mSession ended. Have a great day!\e[0m"
            exit 0
            ;;
    esac
done