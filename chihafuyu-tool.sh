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
# RECOMMENDED APP VERSIONS ARRAYS
# ==============================================================================
cfg_youtube_stable=("20.51.39" "20.47.62" "20.31.42" "20.21.37")
cfg_youtube_music_stable=("9.15.51" "8.51.51" "7.29.52")
cfg_reddit_stable=("2026.14.0" "2026.04.0")
cfg_x_stable=("12.2.0-release.0" "12.0.0-release.0" "11.99.0-release-ripped.1" "11.81.0-release.0" "11.69.0-release.0")
cfg_ig_stable=("435.0.0.37.76")
cfg_adguard_stable=("4.12.81")
cfg_ibispaint_stable=("14.0.4")
cfg_wps_stable=("18.24")
cfg_camscanner_stable=("7.20.0.2606230000")
cfg_sleep_stable=("20260526")
cfg_duolingo_stable=("6.85.7")
cfg_merriamwebster_stable=("Any")
cfg_mimo_stable=("9.11")
cfg_windy_stable=("50.1.1")
cfg_xrecorder_stable=("2.5.1.1")
cfg_xodo_stable=("10.15.0")
cfg_photos_stable=("Any")
cfg_rar_stable=("Any")
cfg_speedtest_stable=("7.0.4")
cfg_stellarium_stable=("1.16.3" "1.16.2")
cfg_proto_stable=("1.49.0" "1.48.0")
cfg_vpnify_stable=("2.2.9")
cfg_backdrops_stable=("6.1.2")
cfg_solidexplorer_stable=("3.4.10")
cfg_pinterest_stable=("14.23.0" "14.24.0")
cfg_chess_stable=("4.10.0" "4.10.0-googleplay" "4.9.49" "4.9.49-googleplay")

# ==============================================================================
# SYSTEM PREREQUISITES
# ==============================================================================
if ! ping -c 1 www.google.com &> /dev/null; then
    echo -e "\e[31m[!] No internet connection detected.\e[0m"
    exit 1
fi

echo -e "\e[36m[SYSTEM] Checking Termux environment prerequisites...\e[0m"
export DEBIAN_FRONTEND=noninteractive

# Auto-Healing
pkill -f "apt" > /dev/null 2>&1 || true
pkill -f "apt-get" > /dev/null 2>&1 || true
pkill -f "dpkg" > /dev/null 2>&1 || true
rm -f "$PREFIX/var/lib/dpkg/lock"* > /dev/null 2>&1
rm -f "$PREFIX/var/cache/apt/archives/lock" > /dev/null 2>&1
rm -f "$PREFIX/var/lib/apt/lists/lock" > /dev/null 2>&1

dpkg --configure -a > /dev/null 2>&1
apt-get --fix-broken install -y -q > /dev/null 2>&1

if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null || ! command -v whiptail &> /dev/null || ! command -v tput &> /dev/null || ! command -v unzip &> /dev/null; then 
    echo -e "\e[90m  [i] Updating and installing core packages...\e[0m"
    apt-get update -y -q > /dev/null 2>&1
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" < /dev/null
    apt-get install -y jq curl whiptail ncurses-utils unzip < /dev/null
    echo -e "\e[32m  [✓] Essential packages installed.\e[0m"
fi 

java_ver=""
if command -v java &> /dev/null; then
    java_ver=$(java -version 2>&1 | grep -oP '"(?:1\.)?\K(\d+)' | head -n 1)
fi

if [ -z "$java_ver" ] || [ "$java_ver" -lt 21 ]; then
    echo -e "\e[35m      Downloading OpenJDK 21 natively via Termux (~100MB+). DO NOT close Termux!\e[0m"
    dpkg --configure -a > /dev/null 2>&1
    apt-get install -y openjdk-21 < /dev/null
fi

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
# UI DIMENSION CALCULATOR & HELPER FUNCTIONS
# ==============================================================================
calc_size() {
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

calc_size
if [ ! -d "$HOME/storage/downloads" ]; then
    whiptail --title "Storage Permission" --msgbox "Termux requires storage permission to save files in your Downloads folder.\n\nPlease tap 'Allow' on the upcoming popup." $WT_H $WT_W
    termux-setup-storage
    sleep 3
    if [ ! -d "$HOME/storage/downloads" ]; then
        echo -e "\e[31m[!] Storage access not granted. Operations cannot continue. Exiting.\e[0m"
        exit 1
    fi
fi

BASE_DIR="$HOME/storage/downloads/Chihafuyu"
mkdir -p "$BASE_DIR/CLI"
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
        # [DEBUG] STRICT DEV CHECK: Only fetch assets from releases explicitly tagged as 'prerelease'
        download_url=$(echo "$api_response" | jq -r ".[] | select(.prerelease == true) | .assets[] | select(.name | endswith(\"$file_ext\")) | .browser_download_url" | head -n 1)
        file_name=$(echo "$api_response" | jq -r ".[] | select(.prerelease == true) | .assets[] | select(.name | endswith(\"$file_ext\")) | .name" | head -n 1)
    fi

    # [DEBUG] Fallback Interception: If a pre-release is missing or lacks the asset, prompt the user to gracefully fallback to stable.
    if [ -z "$download_url" ] || [ "$download_url" == "null" ]; then
        if [ "$track" == "dev" ]; then
            calc_size
            if whiptail --title "Pre-release Not Found" --yesno "No experimental pre-release (dev) file '$file_ext' was found for:\n$repo\n\nWould you like to fallback to the STABLE release instead?" $WT_H $WT_W; then
                fetch_github_artifact "$repo" "stable" "$target_dir" "$file_ext"
                return $?
            else
                return 1
            fi
        else
            calc_size
            whiptail --title "File Not Found" --msgbox "Failed to find '$file_ext' in the releases of:\n$repo ($track)." $WT_H $WT_W
            return 1
        fi
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

load_ecosystem_data() {
    local choice=$1
    app_menu=()
    pkg_map=()
    name_map=()
    keyword_map=()
    array_map=()

    case "$choice" in
        1) 
            project_name="Morphe"; patch_repo="MorpheApp/morphe-patches"
            app_menu=("youtube" "YouTube (Rec: ${cfg_youtube_stable[0]})" ON "ytmusic" "YT Music (Rec: ${cfg_youtube_music_stable[0]})" OFF "reddit" "Reddit (Rec: ${cfg_reddit_stable[0]})" OFF)
            pkg_map["youtube"]="com.google.android.youtube"; name_map["youtube"]="YouTube"; keyword_map["youtube"]="youtube"; array_map["youtube"]="cfg_youtube_stable"
            pkg_map["ytmusic"]="com.google.android.apps.youtube.music"; name_map["ytmusic"]="YT_Music"; keyword_map["ytmusic"]="music"; array_map["ytmusic"]="cfg_youtube_music_stable"
            pkg_map["reddit"]="com.reddit.frontpage"; name_map["reddit"]="Reddit"; keyword_map["reddit"]="reddit"; array_map["reddit"]="cfg_reddit_stable"
            ;;
        2) 
            project_name="Piko"; patch_repo="crimera/piko"
            app_menu=("twitter" "X/Twitter (Rec: ${cfg_x_stable[0]})" ON "instagram" "Instagram (Rec: ${cfg_ig_stable[0]})" OFF)
            pkg_map["twitter"]="com.twitter.android"; name_map["twitter"]="X_Twitter"; keyword_map["twitter"]="twitter\|x"; array_map["twitter"]="cfg_x_stable"
            pkg_map["instagram"]="com.instagram.android"; name_map["instagram"]="Instagram"; keyword_map["instagram"]="instagram\|ig"; array_map["instagram"]="cfg_ig_stable"
            ;;
        3) 
            project_name="hoo-dles"; patch_repo="hoo-dles/morphe-patches"
            app_menu=(
                "adguard" "AdGuard (Rec: ${cfg_adguard_stable[0]})" ON 
                "ibispaint" "IbisPaint X (Rec: ${cfg_ibispaint_stable[0]})" OFF 
                "wps" "WPS Office (Rec: ${cfg_wps_stable[0]})" OFF 
                "camscanner" "CamScanner (Rec: ${cfg_camscanner_stable[0]})" OFF
                "sleep" "Sleep as Android (Rec: ${cfg_sleep_stable[0]})" OFF
                "duolingo" "Duolingo (Rec: ${cfg_duolingo_stable[0]})" OFF
                "merriam" "Merriam-Webster (Rec: Any)" OFF
                "mimo" "Mimo (Rec: ${cfg_mimo_stable[0]})" OFF
                "windy" "Windy (Rec: ${cfg_windy_stable[0]})" OFF
                "xrecorder" "XRecorder (Rec: ${cfg_xrecorder_stable[0]})" OFF
                "xodo" "Xodo (Rec: ${cfg_xodo_stable[0]})" OFF
            )
            pkg_map["adguard"]="com.adguard.android"; name_map["adguard"]="AdGuard"; keyword_map["adguard"]="adguard"; array_map["adguard"]="cfg_adguard_stable"
            pkg_map["ibispaint"]="jp.ne.ibis.ibispaintx.app"; name_map["ibispaint"]="IbisPaint_X"; keyword_map["ibispaint"]="ibis"; array_map["ibispaint"]="cfg_ibispaint_stable"
            pkg_map["wps"]="cn.wps.moffice_eng"; name_map["wps"]="WPS_Office"; keyword_map["wps"]="wps"; array_map["wps"]="cfg_wps_stable"
            pkg_map["camscanner"]="com.intsig.camscanner"; name_map["camscanner"]="CamScanner"; keyword_map["camscanner"]="camscanner"; array_map["camscanner"]="cfg_camscanner_stable"
            pkg_map["sleep"]="com.urbandroid.sleep"; name_map["sleep"]="Sleep_as_Android"; keyword_map["sleep"]="sleep\|urbandroid"; array_map["sleep"]="cfg_sleep_stable"
            pkg_map["duolingo"]="com.duolingo"; name_map["duolingo"]="Duolingo"; keyword_map["duolingo"]="duolingo"; array_map["duolingo"]="cfg_duolingo_stable"
            pkg_map["merriam"]="com.merriamwebster"; name_map["merriam"]="Merriam_Webster"; keyword_map["merriam"]="merriam\|webster"; array_map["merriam"]="cfg_merriamwebster_stable"
            pkg_map["mimo"]="com.getmimo"; name_map["mimo"]="Mimo"; keyword_map["mimo"]="mimo"; array_map["mimo"]="cfg_mimo_stable"
            pkg_map["windy"]="com.windyty.android"; name_map["windy"]="Windy"; keyword_map["windy"]="windy"; array_map["windy"]="cfg_windy_stable"
            pkg_map["xrecorder"]="videoeditor.videorecorder.screenrecorder"; name_map["xrecorder"]="XRecorder"; keyword_map["xrecorder"]="xrecorder\|screenrecorder"; array_map["xrecorder"]="cfg_xrecorder_stable"
            pkg_map["xodo"]="com.xodo.pdf.reader"; name_map["xodo"]="Xodo"; keyword_map["xodo"]="xodo"; array_map["xodo"]="cfg_xodo_stable"
            ;;
        4) 
            project_name="De-ReVanced"; patch_repo="RookieEnough/De-Vanced"
            app_menu=("photos" "Google Photos (Rec: Any)" ON "rar" "RAR (Rec: Any)" OFF)
            pkg_map["photos"]="com.google.android.apps.photos"; name_map["photos"]="Google_Photos"; keyword_map["photos"]="photos"; array_map["photos"]="cfg_photos_stable"
            pkg_map["rar"]="com.rarlab.rar"; name_map["rar"]="RAR"; keyword_map["rar"]="rar"; array_map["rar"]="cfg_rar_stable"
            ;;
        5) 
            project_name="BholeyKaBhakt"; patch_repo="BholeyKaBhakt/android-patches-xtra"
            app_menu=(
                "speedtest" "Speedtest (Rec: ${cfg_speedtest_stable[0]})" ON 
                "stellarium" "Stellarium (Rec: ${cfg_stellarium_stable[0]})" OFF 
                "proto" "PROTO (Rec: ${cfg_proto_stable[0]})" OFF
                "vpnify" "vpnify (Rec: ${cfg_vpnify_stable[0]})" OFF
                "backdrops" "Backdrops (Rec: ${cfg_backdrops_stable[0]})" OFF
                "solid" "Solid Explorer (Rec: ${cfg_solidexplorer_stable[0]})" OFF
            )
            pkg_map["speedtest"]="org.zwanoo.android.speedtest"; name_map["speedtest"]="Speedtest"; keyword_map["speedtest"]="speedtest"; array_map["speedtest"]="cfg_speedtest_stable"
            pkg_map["stellarium"]="com.noctuasoftware.stellarium_free"; name_map["stellarium"]="Stellarium"; keyword_map["stellarium"]="stellarium"; array_map["stellarium"]="cfg_stellarium_stable"
            pkg_map["proto"]="com.proto.circuitsimulator"; name_map["proto"]="PROTO"; keyword_map["proto"]="proto\|circuit"; array_map["proto"]="cfg_proto_stable"
            pkg_map["vpnify"]="com.vpn.free.hotspot.secure.vpnify"; name_map["vpnify"]="vpnify"; keyword_map["vpnify"]="vpnify"; array_map["vpnify"]="cfg_vpnify_stable"
            pkg_map["backdrops"]="com.backdrops.wallpapers"; name_map["backdrops"]="Backdrops"; keyword_map["backdrops"]="backdrops"; array_map["backdrops"]="cfg_backdrops_stable"
            pkg_map["solid"]="pl.solidexplorer2"; name_map["solid"]="Solid_Explorer"; keyword_map["solid"]="solid\|explorer"; array_map["solid"]="cfg_solidexplorer_stable"
            ;;
        6) 
            project_name="browzomje"; patch_repo="browzomje/browzomje-patches"
            app_menu=("pinterest" "Pinterest (Rec: ${cfg_pinterest_stable[0]})" ON)
            pkg_map["pinterest"]="com.pinterest"; name_map["pinterest"]="Pinterest"; keyword_map["pinterest"]="pinterest"; array_map["pinterest"]="cfg_pinterest_stable"
            ;;
        7) 
            project_name="PathxmOp"; patch_repo="PathxmOp/patches"
            app_menu=("chess" "Chess.com (Rec: ${cfg_chess_stable[0]})" ON)
            pkg_map["chess"]="com.chess"; name_map["chess"]="Chess"; keyword_map["chess"]="chess\|^\d\{5,8\}_"; array_map["chess"]="cfg_chess_stable"
            ;;
    esac
}

# ==============================================================================
# WORKFLOW: UTILITIES (Ported from PowerShell)
# ==============================================================================
invoke_utility() {
    calc_size
    local utilChoice=$(whiptail --title "UTILITY MENU" --menu "Select Utility Action:" $WT_H $WT_W $WT_M \
        "1" "Generate Options only" \
        "2" "Generate list-patches only" \
        "3" "Generate Custom Keystore (PKCS12)" \
        "4" "Clear Morphe Cache" \
        "B" "Back to Main Menu" 3>&1 1>&2 2>&3)
        
    if [[ -z "$utilChoice" || "$utilChoice" == "B" || "$utilChoice" == "b" ]]; then return; fi
    
    # 3. Keystore Generation (No CLI needed)
    if [ "$utilChoice" == "3" ]; then
        calc_size
        local ksName=$(whiptail --title "Custom Keystore" --inputbox "Enter filename (e.g., my-key.keystore):" $WT_H $WT_W 3>&1 1>&2 2>&3)
        if [ -z "$ksName" ]; then return; fi
        
        # Append extension if missing
        if [[ "$ksName" != *.* ]]; then ksName="${ksName}.keystore"; fi
        local ksPath="$BASE_DIR/$ksName"
        
        if [ -f "$ksPath" ]; then
            calc_size
            whiptail --title "Error" --msgbox "File '$ksName' already exists in the Downloads folder!" $WT_H $WT_W
            return
        fi

        calc_size
        local ksAlias=$(whiptail --title "Custom Keystore" --inputbox "Enter Alias (e.g., Morphe):" $WT_H $WT_W 3>&1 1>&2 2>&3)
        calc_size
        local ksPass=$(whiptail --title "Custom Keystore" --passwordbox "Enter Password (min 6 chars):" $WT_H $WT_W 3>&1 1>&2 2>&3)
        calc_size
        local ksSigner=$(whiptail --title "Custom Keystore" --inputbox "Enter Signer Name (Max 8 chars, no spaces):" $WT_H $WT_W 3>&1 1>&2 2>&3)
        calc_size
        local ksOU=$(whiptail --title "Custom Keystore" --inputbox "Enter Organizational Unit (e.g., Modder):" $WT_H $WT_W 3>&1 1>&2 2>&3)
        calc_size
        local ksOrg=$(whiptail --title "Custom Keystore" --inputbox "Enter Organization (e.g., MyCompany):" $WT_H $WT_W 3>&1 1>&2 2>&3)
        calc_size
        local ksCountry=$(whiptail --title "Custom Keystore" --inputbox "Enter 2-letter Country Code (e.g., ID, US):" $WT_H $WT_W 3>&1 1>&2 2>&3)

        clear
        echo -e "\e[36m[*] Generating PKCS12 Keystore via Java keytool...\e[0m"
        keytool -genkeypair -v -keystore "$ksPath" -alias "$ksAlias" -keyalg RSA -keysize 4096 -validity 10000 -storepass "$ksPass" -keypass "$ksPass" -dname "CN=$ksSigner, OU=$ksOU, O=$ksOrg, C=${ksCountry^^}" -storetype PKCS12 2>&1
        
        if [ $? -eq 0 ] && [ -f "$ksPath" ]; then
            echo -e "\e[32m[✓] Keystore generated successfully at: $ksPath\e[0m"
        else
            echo -e "\e[31m[!] Failed to generate keystore.\e[0m"
        fi
        read -p "Press Enter to continue..."
        return
    fi

    # Fetch CLI for 1, 2, 4
    if [[ "$utilChoice" =~ ^[124]$ ]]; then
        calc_size
        local cliTrack=$(whiptail --title "CLI Environment" --menu "Select Morphe CLI Track for Utility:" $WT_H $WT_W $WT_M "stable" "Recommended Release" "dev" "Experimental Pre-release" 3>&1 1>&2 2>&3)
        if [ -z "$cliTrack" ]; then return; fi
        local cli_repo="MorpheApp/morphe-cli"
        fetch_github_artifact "$cli_repo" "$cliTrack" "$BASE_DIR/CLI" ".jar" || return
        local cliJar="$FETCHED_FILE"
    fi

    # 4. Clear Cache
    if [ "$utilChoice" == "4" ]; then
        clear
        echo -e "\e[36m[*] Clearing Morphe temporary files and cache...\e[0m"
        java -jar "$cliJar" utility clear-cache --info
        echo -e "\e[32m[✓] Cache cleared successfully.\e[0m"
        read -p "Press Enter to continue..."
        return
    fi

    # 1 & 2. Options and List-Patches Generator
    if [[ "$utilChoice" == "1" || "$utilChoice" == "2" ]]; then
        calc_size
        local patchesTrack=$(whiptail --title "Patches Environment" --menu "Select Ecosystem Patches Track:" $WT_H $WT_W $WT_M "stable" "Recommended Release" "dev" "Experimental Pre-release" 3>&1 1>&2 2>&3)
        if [ -z "$patchesTrack" ]; then return; fi

        calc_size
        local ecoChoice=$(whiptail --title "Target Ecosystem" --menu "Select Ecosystem(s):" $WT_H $WT_W $WT_M "1" "Morphe" "2" "Piko" "3" "hoo-dles" "4" "De-ReVanced" "5" "BholeyKaBhakt" "6" "browzomje" "7" "PathxmOp" 3>&1 1>&2 2>&3)
        if [ -z "$ecoChoice" ]; then return; fi

        load_ecosystem_data "$ecoChoice"
        workspace="$BASE_DIR/$project_name"
        mkdir -p "$workspace/Input" "$workspace/Output"

        fetch_github_artifact "$patch_repo" "$patchesTrack" "$workspace" ".mpp" || return
        local patchesFile="$FETCHED_FILE"
        
        local extraPatchFile=""
        if [ "$ecoChoice" -eq 2 ]; then
            fetch_gitlab_artifact "inotia00%2Fx-shim" "$workspace" ".mpp" || return
            extraPatchFile="$FETCHED_FILE"
        fi

        if [ "$utilChoice" == "1" ]; then
            clear
            echo -e "\e[36m[*] Generating Options JSON for $project_name...\e[0m"
            for key in "${!pkg_map[@]}"; do
                local t_pkg="${pkg_map[$key]}"
                local t_name="${name_map[$key]}"
                local jsonFile="$workspace/${t_name}-options.json"
                
                echo -e "  -> Generating for $t_pkg"
                local optArgs=("-jar" "$cliJar" "options-create" "--patches" "$patchesFile")
                if [ -n "$extraPatchFile" ]; then optArgs+=("--patches" "$extraPatchFile"); fi
                optArgs+=("--out" "$jsonFile" "--filter-package-name" "$t_pkg")
                java "${optArgs[@]}" >/dev/null 2>&1
            done
            echo -e "\e[32m[✓] Saved options to Downloads/Chihafuyu/$project_name/\e[0m"
            read -p "Press Enter to continue..."
        elif [ "$utilChoice" == "2" ]; then
            clear
            local patchesListFile="$workspace/list-patches-$patchesTrack.txt"
            echo -e "\e[36m[*] Generating list-patches reference for $project_name...\e[0m"
            
            local incExp=0
            calc_size
            if whiptail --title "Include Experimental" --yesno "Include experimental app versions in the output? (--include-experimental)" $WT_H $WT_W; then
                incExp=1
            fi
            
            local listArgs=("-jar" "$cliJar" "list-patches" "--with-packages" "--with-versions" "--with-options" "--out" "$patchesListFile" "--patches" "$patchesFile")
            if [ "$incExp" -eq 1 ]; then listArgs+=("--include-experimental"); fi
            if [ -n "$extraPatchFile" ]; then listArgs+=("--patches" "$extraPatchFile"); fi
            
            java "${listArgs[@]}" >/dev/null 2>&1
            echo -e "\e[32m[✓] Reference file created at: $patchesListFile\e[0m"
            read -p "Press Enter to continue..."
        fi
    fi
}

# ==============================================================================
# WORKFLOW: PATCHING (Includes Global Advanced Preferences)
# ==============================================================================
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
        "3" "hoo-dles (AdGuard, IbisPaint X, WPS, etc.)" \
        "4" "De-ReVanced (Google Photos, RAR)" \
        "5" "BholeyKaBhakt (Speedtest, Stellarium, etc.)" \
        "6" "browzomje (Pinterest)" \
        "7" "PathxmOp (Chess.com)" 3>&1 1>&2 2>&3)
    if [ -z "$ecoChoice" ]; then return; fi

    load_ecosystem_data "$ecoChoice"
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

    # [DEBUG] Dynamic Array Validation & Mismatch Gating
    local valid_targets=()
    for tag in $appChoices; do
        local a_name="${name_map[$tag]}"
        local k_word="${keyword_map[$tag]}"
        local arr_name="${array_map[$tag]}"
        
        declare -n stable_arr="$arr_name"
        
        local found_apk=""
        local target_version=""
        local status_tag="[MISMATCH]"
        local prompt_again=true

        while [ "$prompt_again" = true ]; do
            found_apk=$(find "$workspace/Input" -maxdepth 1 -type f -iregex ".*\(${k_word}\).*\.\(apk\|apkm\|xapk\|apks\)$" | head -n 1)
            
            # [DEBUG] ZIP validation check native to bash using unzip. Mimics Test-IsUniversalApk in PS1.
            if [ -n "$found_apk" ] && [[ "$found_apk" == *.apk ]]; then
                if ! unzip -l "$found_apk" 2>/dev/null | grep -q "classes.dex" || ! unzip -l "$found_apk" 2>/dev/null | grep -q "AndroidManifest.xml"; then
                    calc_size
                    if whiptail --title "Corrupt/Split APK" --yesno "WARNING: The file $(basename "$found_apk") appears to be missing core files (classes.dex / AndroidManifest.xml).\n\nAre you sure you want to force continue anyway?" $WT_H $WT_W; then
                        :
                    else
                        found_apk=""
                    fi
                fi
            fi

            if [ -n "$found_apk" ]; then
                target_version=$(echo "$(basename "$found_apk")" | grep -oP '(\d+\.\d+(?:\.\d+)*(?:-(?:release|alpha|beta|rc|ripped|release-ripped)(?:\.\d+)+)?|\d+(?:[-_]\d+)+(?:-(?:release|alpha|beta|rc|ripped|release-ripped)(?:\.\d+)+)?|\b\d{7,}\b)' | sed 's/[-_]/./g' | head -n 1)
                
                status_tag="[MISMATCH]"
                for rec_v in "${stable_arr[@]}"; do
                    if [[ "$rec_v" == "Any" || "$rec_v" == "$target_version" ]]; then
                        if [[ "$rec_v" == "Any" ]]; then
                            status_tag="[SUPPORTED]"
                        else
                            status_tag="[RECOMMENDED]"
                        fi
                        break
                    fi
                done
                
                if [[ "$status_tag" == "[MISMATCH]" ]]; then
                    calc_size
                    local rec_list="${stable_arr[*]}"
                    if whiptail --title "Version Mismatch!" --yesno "Warning: Found $(basename "$found_apk")\n\nDetected Version: $target_version\nRecommended Versions: $rec_list\n\nPatching an unsupported version may cause the app to crash.\nDo you want to FORCE PATCH this version anyway?" $WT_H $WT_W; then
                        prompt_again=false
                    else
                        found_apk=""
                        prompt_again=false
                    fi
                else
                    prompt_again=false
                fi
            else
                calc_size
                if whiptail --title "APK Not Found / Skipped" --yesno "Missing valid APK file for $a_name!\n\nPlease download the APK and place it inside:\nDownloads/Chihafuyu/$project_name/Input/\n\nSelect 'Yes' to check the folder again, or 'No' to skip this app." $WT_H $WT_W; then
                    continue
                else
                    break
                fi
            fi
        done

        if [ -n "$found_apk" ]; then
            valid_targets+=("$tag|$found_apk|$status_tag")
        fi
    done

    if [ ${#valid_targets[@]} -eq 0 ]; then
        calc_size
        whiptail --title "Abort" --msgbox "No valid APKs were provided. Aborting workflow." $WT_H $WT_W
        return
    fi

    # [DEBUG] Ported Global Execution Preferences
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
        1) arch_flag="arm64-v8a" ;; 2) arch_flag="armeabi-v7a" ;; 3) arch_flag="x86_64" ;; 4) arch_flag="x86" ;; 5) arch_flag="" ;;
    esac

    local bytecodeMode=""
    calc_size
    if whiptail --title "Bytecode Mode" --yesno "Configure custom bytecode mode? (--bytecode-mode)" $WT_H $WT_W; then
        calc_size
        local bcChoice=$(whiptail --title "Bytecode Mode" --menu "Select Mode:" $WT_H $WT_W $WT_M "1" "FULL" "2" "STRIP_FAST" "3" "STRIP_SAFE" 3>&1 1>&2 2>&3)
        case "$bcChoice" in
            1) bytecodeMode="FULL" ;; 2) bytecodeMode="STRIP_FAST" ;; 3) bytecodeMode="STRIP_SAFE" ;;
        esac
    fi

    local continueOnError=0
    calc_size
    if whiptail --title "Error Handling" --yesno "Skip failed patches and continue to the next APK? (--continue-on-error)" $WT_H $WT_W; then
        continueOnError=1
    fi

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
        local tmp="${target#*|}"
        local t_apk="${tmp%|*}"
        local t_status="${target##*|}"
        
        local t_name="${name_map[$t_tag]}"
        local jsonFile="$workspace/${t_name}-options.json"
        local tempResultFile="$workspace/Output/temp_result_$t_name.json"
        
        apkName=$(basename "$t_apk")
        
        local c_status=""
        if [ "$t_status" == "[MISMATCH]" ]; then
            c_status="\e[33m$t_status\e[0m"
        else
            c_status="\e[32m$t_status\e[0m"
        fi
        
        echo -e "\n\e[35m>>> PATCHING: $apkName $c_status <<<\e[0m"
        echo ">>> PATCHING: $apkName $t_status <<<" >> "$temp_log"
        
        outputApkAbs="$workspace/Output/Patched_${apkName%.*}.apk"
        
        baseArgs=("-Xmx$heapSize" "-jar" "$cliJar" "patch" "--patches" "$patchesFile")
        if [ -n "$extraPatchFile" ]; then baseArgs+=("--patches" "$extraPatchFile"); fi
        
        baseArgs+=("--options-file" "$jsonFile" "--out" "$outputApkAbs" "--result-file" "$tempResultFile")
        
        if [ -n "$arch_flag" ]; then baseArgs+=("--striplibs" "$arch_flag"); fi
        if [ -n "$bytecodeMode" ]; then baseArgs+=("--bytecode-mode" "$bytecodeMode"); fi
        if [ "$continueOnError" -eq 1 ]; then baseArgs+=("--continue-on-error"); fi

        if [ "$disableSigning" -eq 1 ]; then
            baseArgs+=("--unsigned")
        elif [ "$useCustomKeystore" -eq 1 ]; then
            baseArgs+=("--keystore" "$keystoreFile" "--keystore-entry-alias" "$keystoreAlias" "--keystore-password" "$plainPass" "--keystore-entry-password" "$plainEntryPass")
        fi
        
        baseArgs+=("$t_apk")
        
        java "${baseArgs[@]}" 2>&1 | tee -a "$temp_log"
        
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo -e "\e[31m[!] Patching FAILED\e[0m\n"
            echo "[!] Patching FAILED" >> "$temp_log"
            if [ "$continueOnError" -eq 0 ]; then break; fi
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

    # [DEBUG] Ported Export Result JSONs logic
    calc_size
    if whiptail --title "Export Results" --yesno "Do you want to export the patching result JSONs? (--result-file)" $WT_H $WT_W; then
        for target in "${valid_targets[@]}"; do
            local t_tag="${target%%|*}"
            local t_name="${name_map[$t_tag]}"
            local tempResultFile="$workspace/Output/temp_result_$t_name.json"
            
            if [ -f "$tempResultFile" ]; then
                local finalResultName="Result_${t_name}_$(date +%Y%m%d_%H%M%S).json"
                mv "$tempResultFile" "$workspace/Output/$finalResultName"
                echo -e "\e[90m[i] JSON result exported to $finalResultName\e[0m"
            fi
        done
    else
        # Cleanup temporary result files if export is declined
        for target in "${valid_targets[@]}"; do
            local t_tag="${target%%|*}"
            local t_name="${name_map[$t_tag]}"
            rm -f "$workspace/Output/temp_result_$t_name.json"
        done
    fi

    read -p "Press Enter to return to the Main Menu..."
}

while true; do
    calc_size
    mainChoice=$(whiptail --title "CHIHAFUYU TOOL" --menu "What do you want to do?" $WT_H $WT_W $WT_M \
        "1" "Patch apps" \
        "2" "Use utilities" \
        "X" "Close" 3>&1 1>&2 2>&3)
    
    case "${mainChoice,,}" in
        1) invoke_patching ;;
        2) invoke_utility ;;
        x|"")
            clear
            echo -e "\e[36mSession ended. Have a great day!\e[0m"
            exit 0
            ;;
    esac
done