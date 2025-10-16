## Get-ZimmermanTools (Linux/Mac)

> NOTE: I am not affiliated with Eric Zimmerman or his tools. This script is a simple wrapper to automate the installation of his tools. All credit for the tools goes to Eric Zimmerman and his team.

### Compatibility

| Tool                  | Platform Support               |
| --------------------- | ------------------------------ |
| AmcacheParser         | Native ✅                      |
| AppCompatCacheParser  | Native ✅                      |
| bstrings              | Native ✅                      |
| EvtxECmd              | Native ✅                      |
| EZViewer              | Partially Compatible (wine) ⚠️ |
| Hasher                | No .NET 9 Binary ❌            |
| JLECmd                | Native ✅                      |
| JumpListExplorer      | Partially Compatible (wine) ⚠️ |
| LECmd                 | Native ✅                      |
| MFTECmd               | Native ✅                      |
| MFTExplorer           | Partially Compatible (wine) ⚠️ |
| PECmd                 | Incompatible ❌                |
| RBCmd                 | Native ✅                      |
| RecentFileCacheParser | Native ✅                      |
| RECmd                 | Native ✅                      |
| RegistryExplorer      | Partially Compatible (wine) ⚠️ |
| RLA                   | Native ✅                      |
| SDBExplorer           | Partially Compatible (wine) ⚠️ |
| SBECmd                | Native ✅                      |
| ShellBagsExplorer     | Partially Compatible (wine) ⚠️ |
| SQLECmd               | Native ✅                      |
| SrumECmd              | Native ✅                      |
| SumECmd               | Incompatible ❌                |
| TimelineExplorer      | Partially Compatible (wine) ⚠️ |
| VSCMount              | Incompatible ❌                |
| WxTCmd                | Native ✅                      |

Tested on:

- Linux (Ubuntu 24.04, x64)
- macOS (Tahoe 26.0.1, arm)

> NOTE: I was unable to succeed in getting the wine compatible tools to work in M-Series Macs. Feel free to submit a PR if you succeed!

### Overview

This script automates downloading and installing Eric Zimmerman's forensic tools built for .NET 9 on Linux and macOS. Tools are installed under `/opt/eztools/<ToolName>` and require sudo privileges.

### Features

- **Install**: Fetch and install a curated set of Zimmerman tools.
- **Update**: With `--update`, re-install a tool only when a new archive hash is detected.
- **Purge**: With `--purge`, remove everything under `/opt/eztools`.
- **Logging**: Appends CSV entries to `/opt/eztools/install_log.csv` with `timestamp,tool,sha256` for each successful install.

### Requirements

- **.NET Runtime 9.x** (the script verifies that `dotnet --version` starts with `9.`)
- **wget** and **unzip** installed
- **sha256sum** or **shasum** for hash logging (optional but recommended)
- **sudo privileges** (script manages `/opt/eztools`)

### Install Directory and Permissions

- Base directory: `/opt/eztools`
- Each tool installs into: `/opt/eztools/<ToolName>`
- The script will create `/opt/eztools` (and tool directories) as needed.
- Non-root execution is supported if passwordless sudo is available; otherwise run with `sudo`.

### Usage

Run the script from this repository directory:

```bash
sudo ./Get-ZimmermanTools.sh
```

#### Install (default behavior)

- Installs tools that are not already present.
- If a tool directory exists and `--update` is not specified, it will be skipped.

#### Update (hash-aware overwrite)

Use `--update` to reinstall a tool only when the downloaded archive hash is new for that tool.

```bash
sudo ./Get-ZimmermanTools.sh --update
# or shorthand
sudo ./Get-ZimmermanTools.sh -u
```

Update logic:

- The script downloads the ZIP, computes its SHA-256, and checks `install_log.csv` for a matching `tool,hash` pair.
- If the hash is already logged for that tool, the tool is considered up-to-date and is skipped.
- If the hash is new, the existing tool directory is removed and replaced with the new content.

#### Purge (remove all tools)

Deletes the entire install directory and exits.

```bash
sudo ./Get-ZimmermanTools.sh --purge
# or shorthand
sudo ./Get-ZimmermanTools.sh -p
```

Safety guard ensures only `/opt/eztools` is purged.

#### Help

```bash
./Get-ZimmermanTools.sh --help
```

### Logging

The script writes a CSV log to `/opt/eztools/install_log.csv` using UTC timestamps:

```
timestamp,tool,sha256
2025-01-01T12:34:56Z,MFTECmd,abcdef1234...
```

- The log is created with a header if missing.
- SHA-256 is computed with `sha256sum` or `shasum -a 256`.
- If no hashing tool is found, the hash column will be empty for that entry, and the `--update` logic will not detect duplicates reliably.

### Troubleshooting

- **.NET version not 9.x**: Install the required runtime (`https://dotnet.microsoft.com/download`).
- **wget/unzip not found**: Install via your package manager.
- **Permission denied**: Re-run with `sudo` or configure passwordless sudo.
- **Update skipped unexpectedly**: Ensure `sha256sum` or `shasum` is installed so hashes can be computed. Check that `install_log.csv` is writable.

### Attribution

This installer fetches binaries from `https://download.ericzimmermanstools.com/net9`. All tool copyrights and licenses belong to Eric Zimmerman and respective authors.
