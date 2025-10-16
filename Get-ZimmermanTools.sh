#!/usr/bin/env bash

# Enable strict error handling
set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
UPDATE=false
SHOW_HELP=false
PURGE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--update)
            UPDATE=true
            shift
            ;;
        -p|--purge)
            PURGE=true
            shift
            ;;
        -h|--help)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Show help if requested
if [[ "$SHOW_HELP" == true ]]; then
    echo -e "Usage: $0 [OPTIONS]"
    echo ""
    echo "Download and install Eric Zimmerman's forensic tools"
    echo ""
    echo "OPTIONS:"
    echo "  -u, --update       Update tools if new archive hash detected"
    echo "  -p, --purge        Purge all tools (deletes /opt/eztools)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 # Install tools, skip existing ones"
    echo "  $0 --update        # Install tools, replace only if new hash"
    echo "  $0 --purge         # Remove all tools under /opt/eztools"
    exit 0
fi

# Ensure sudo/root privileges are available early
echo -e "[*] Checking for sudo/root privileges..."
if [[ $EUID -ne 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
        echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} This script requires sudo privileges to manage /opt installations"
        echo -e "${YELLOW}Re-run with:${NC} sudo $0 [options]"
        exit 1
    fi
fi

# Handle purge option early and exit
if [[ "$PURGE" == true ]]; then
    BASE_DIR="/opt/eztools"
    echo -e "${YELLOW}[!]${NC} ${YELLOW}PURGE:${NC} Recursively deleting ${BASE_DIR}"
    if [[ -n "$BASE_DIR" && "$BASE_DIR" == "/opt/eztools" ]]; then
        if sudo rm -rf "$BASE_DIR" 2>/dev/null; then
            echo -e "${GREEN}[+]${NC} ${GREEN}Purged ${BASE_DIR}${NC}"
            exit 0
        else
            echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} Failed to purge ${BASE_DIR}"
            exit 1
        fi
    else
        echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} Safety check failed, refusing to purge path: '$BASE_DIR'"
        exit 1
    fi
fi

# Check if dotnet is installed and version 9.x
echo -e "[*] Checking .NET runtime requirements..."
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} .NET runtime not found. Please install .NET 9.x first."
    echo -e "${YELLOW}Visit:${NC} https://dotnet.microsoft.com/download"
    exit 1
fi

# Check dotnet version
dotnet_version=$(dotnet --version 2>/dev/null || echo "")
if [[ -z "$dotnet_version" ]]; then
    echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} Failed to get .NET version"
    exit 1
fi

# Check if version starts with "9."
if [[ ! "$dotnet_version" =~ ^9\. ]]; then
    echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} .NET version $dotnet_version detected, but .NET 9.x is required"
    echo -e "${YELLOW}Current version:${NC} $dotnet_version"
    echo -e "${YELLOW}Required version:${NC} 9.x"
    echo -e "${YELLOW}Visit:${NC} https://dotnet.microsoft.com/download"
    exit 1
fi

echo -e "${GREEN}[+]${NC} ${GREEN}.NET runtime check passed${NC} (version: $dotnet_version)"
echo ""

BASE_URL="https://download.ericzimmermanstools.com/net9"
BASE_DIR="/opt/eztools"

# Ensure base install directory exists
echo -e "[*] Ensuring base directory exists: ${BASE_DIR}"
if ! sudo mkdir -p "$BASE_DIR" 2>/dev/null; then
    echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} Failed to create base directory $BASE_DIR"
    exit 1
fi

# Prepare install log
LOG_FILE="${BASE_DIR}/install_log.csv"
HASH_TOOL=""
if command -v sha256sum >/dev/null 2>&1; then
    HASH_TOOL="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    HASH_TOOL="shasum"
else
    echo -e "${YELLOW}[!]${NC} ${YELLOW}WARNING:${NC} No SHA-256 tool found (sha256sum/shasum); install log will omit hashes"
fi

# Initialize CSV header if file missing
if [[ ! -f "$LOG_FILE" ]]; then
    echo "timestamp,tool,sha256" | sudo tee "$LOG_FILE" > /dev/null
fi
TOOLS_TO_DOWNLOAD=(
    "AmcacheParser"
    "AppCompatCacheParser"
    "bstrings"
    "EvtxECmd"
    "EZViewer"
    "JLECmd"
    "JumpListExplorer"
    "LECmd"
    "MFTECmd"
    "MFTExplorer"
    "PECmd"
    "RBCmd"
    "RecentFileCacheParser"
    "RECmd"
    "RegistryExplorer"
    "rla"
    "SDBExplorer"
    "SBECmd"
    "ShellBagsExplorer"
    "SQLECmd"
    "SrumECmd"
    "SumECmd"
    "TimelineExplorer"
    "VSCMount"
    "WxTCmd"
)

# Initialize counters for error tracking
failed_downloads=()
successful_downloads=()
skipped_downloads=()

for tool in "${TOOLS_TO_DOWNLOAD[@]}"; do
    echo "[*] Processing $tool..."
    
    # Create temporary file path
    temp_zip="/tmp/${tool}.zip"
    target_dir="${BASE_DIR}/${tool}"
    
    # Download the tool
    if ! wget "${BASE_URL}/${tool}.zip" -O "$temp_zip" 2>/dev/null; then
        echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} Failed to download $tool"
        failed_downloads+=("$tool")
        continue
    fi
    
    # Verify download was successful (file exists and has content)
    if [[ ! -f "$temp_zip" || ! -s "$temp_zip" ]]; then
        echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} Downloaded file for $tool is empty or missing"
        failed_downloads+=("$tool")
        continue
    fi

    # Compute SHA-256 of the downloaded archive
    if [[ -n "$HASH_TOOL" ]]; then
        if [[ "$HASH_TOOL" == "sha256sum" ]]; then
            zip_sha256=$(sha256sum "$temp_zip" | awk '{print $1}')
        else
            zip_sha256=$(shasum -a 256 "$temp_zip" | awk '{print $1}')
        fi
    else
        zip_sha256=""
    fi

    # Decide update/skip based on existing installation and log
    if [[ -d "$target_dir" ]]; then
        if [[ "$UPDATE" == true ]]; then
            if [[ -n "$zip_sha256" ]] && grep -q ",${tool},${zip_sha256}$" "$LOG_FILE" 2>/dev/null; then
                echo -e "${YELLOW}[~]${NC} ${YELLOW}SKIP:${NC} $tool is up-to-date (hash present in log)"
                rm -f "$temp_zip"
                skipped_downloads+=("$tool")
                continue
            else
                echo -e "${YELLOW}[!]${NC} ${YELLOW}UPDATE:${NC} New archive detected for $tool; replacing existing installation"
                if ! sudo rm -rf "$target_dir" 2>/dev/null; then
                    echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} Failed to remove existing installation of $tool"
                    failed_downloads+=("$tool")
                    rm -f "$temp_zip"
                    continue
                fi
            fi
        else
            echo -e "${YELLOW}[~]${NC} ${YELLOW}SKIP:${NC} $tool already exists at $target_dir (use --update to replace when new version)"
            rm -f "$temp_zip"
            skipped_downloads+=("$tool")
            continue
        fi
    fi
    
    # Create target directory
    if ! sudo mkdir -p "$target_dir" 2>/dev/null; then
        echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} Failed to create directory $target_dir"
        failed_downloads+=("$tool")
        rm -f "$temp_zip"
        continue
    fi
    
    # Extract the archive
    if ! sudo unzip -q "$temp_zip" -d "$target_dir" 2>/dev/null; then
        echo -e "${RED}[!]${NC} ${RED}ERROR:${NC} Failed to extract $tool"
        failed_downloads+=("$tool")
        rm -f "$temp_zip"
        continue
    fi
    
    # Append to install log only after successful extraction
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "$timestamp,$tool,$zip_sha256" | sudo tee -a "$LOG_FILE" > /dev/null

    # Clean up temporary file
    if ! rm -f "$temp_zip" 2>/dev/null; then
        echo -e "${YELLOW}[!]${NC} ${YELLOW}WARNING:${NC} Failed to remove temporary file $temp_zip"
    fi
    
    echo -e "${GREEN}[+]${NC} ${GREEN}Successfully installed $tool${NC}"
    successful_downloads+=("$tool")
done

# Print summary
echo ""
echo -e "=== Installation Summary ==="
echo -e "Successfully installed: ${#successful_downloads[@]} tools"
if [[ ${#successful_downloads[@]} -gt 0 ]]; then
    echo -e "Successful tools: ${successful_downloads[*]}"
fi

echo -e "Skipped (already exist): ${#skipped_downloads[@]} tools"
if [[ ${#skipped_downloads[@]} -gt 0 ]]; then
    echo -e "Skipped tools: ${skipped_downloads[*]}"
fi

echo -e "Failed installations: ${#failed_downloads[@]} tools"
if [[ ${#failed_downloads[@]} -gt 0 ]]; then
    echo -e "Failed tools: ${failed_downloads[*]}"
    echo ""
    echo "You may want to retry failed downloads manually:"
    for tool in "${failed_downloads[@]}"; do
        echo "  wget ${BASE_URL}/${tool}.zip -O /tmp/${tool}.zip"
    done
fi