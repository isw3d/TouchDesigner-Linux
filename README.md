# TouchDesigner-Linux

Automated installer to run TouchDesigner on Linux with a standalone Soda Wine runner (no Bottles required).

![Screenshot](Screenshots/0.png)

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/isw3d/TouchDesigner-Linux/main/install.sh | bash
```

## For dev

```bash
curl -sSL https://raw.githubusercontent.com/isw3d/TouchDesigner-Linux/test/script-integration/install.sh | bash

This script installs system dependencies, Wine runner, Winetricks components, TouchDesigner launcher, and optional desktop integration.

## What The Installer Does

1. Detects distro and package manager.
2. Installs required Linux packages.
3. Downloads and configures Soda Wine runner.
4. Initializes a dedicated Wine prefix.
5. Installs Windows dependencies with Winetricks.
6. Lets you choose a TouchDesigner version and run the installer.
7. Creates launcher, desktop shortcut, app-menu entry, and optional .toe association.

## Supported Distros

The script autodetects and supports package installation on:

- Arch-based (pacman)
- Ubuntu/Debian-based (apt)
- Fedora/RHEL-based (dnf)
- openSUSE/SUSE-based (zypper)

## Runtime Expectations

- Initial full setup can be long. It can take around 50-60 minutes depending on network and machine speed.
- Running TouchDesigner installer itself is the slowest task in this install.
- First launch of TouchDesigner can take 1 to 2 minutes.

This is all normal.

## Useful Paths

- Launcher script: ~/.local/bin/launch-touchdesigner.sh
- Desktop shortcut: ~/Desktop/TouchDesigner.desktop
- App menu entry: ~/.local/share/applications/touchdesigner.desktop
- File association entry: ~/.local/share/applications/touchdesigner-file.desktop
- Wine prefix + assets base: ~/.local/share/touchdesigner-linux
- Optional font fix file: ~/.local/share/touchdesigner-linux/wine_ui_fixes.tox

## Troubleshooting

### No display / installer GUI fails

Symptoms include Wine window creation errors.

Check that you run from a graphical session with DISPLAY or WAYLAND_DISPLAY set.

### Version list fetch fails

If the Derivative website is slow/unreachable, the script falls back to a curated list of known versions automatically.

### Long dependency phase

If output seems quiet during Windows dependency installation, wait: the step is often long and expected.

### Duplicate menu entry

The .toe association entry is hidden from app menu by default (NoDisplay=true). If old duplicates remain, remove stale .desktop files in ~/.local/share/applications and refresh desktop database.

## File Association Behavior

- The launcher accepts file URIs and normal paths.
- .toe association uses %u and the launcher handles path conversion.

## Uninstall

Run installer again and choose Uninstall.

This removes runner, prefix, launcher, desktop entries, and file association files created by this script.

## Compatibility Notes

Observed on recent NVIDIA + Wayland setups:

- Launch and runtime: working
- UI rendering: working with wine_ui_fixes.tox
- NDI and TD-Bitwig: working in tested setups
- Video Device In: partial (device may lock until restart/replug)
- NVIDIA TOP: not working in this Wine environment (CUDA/TensorRT init issues)

## Screenshots

![Setup](Screenshots/1.png)
![Dependencies](Screenshots/2.png)
![Run executable](Screenshots/3.png)
![Launch](Screenshots/4.png)
![Font fix](Screenshots/5.png)
![Optional setup](Screenshots/6.png)
![Toe icon example](Screenshots/7.png)

Built with care.

Iswad


______



# TouchDesigner on Linux (via Bottles)

![Screenshot](Screenshots/0.png)

TouchDesigner is not officially supported on Linux, but it can run very well through Bottles **(Wayland)**.

This guide gives a complete, working setup.

## Table of Contents

- [1. Install Bottles](#1-install-bottles)
- [2. Create the TouchDesigner Bottle](#2-create-the-touchdesigner-bottle)
- [3. Install Dependencies](#3-install-dependencies)
- [4. Install TouchDesigner](#4-install-touchdesigner)
- [5. Launch TouchDesigner](#5-launch-touchdesigner)
- [6. Fix Missing Fonts](#6-fix-missing-fonts)
- [7. Optional: Flatpak Filesystem Access](#7-optional-flatpak-filesystem-access)
- [8. Optional: Desktop Integration](#8-optional-desktop-integration)
- [9. Screenshots](#9-screenshots)
- [10. Compatibility Status](#10-compatibility-status)
- [11. Notes](#11-notes)

---

## 1. Install Bottles

Install Bottles using one of the methods below.

### Flatpak (recommended on Fedora, Mint, and similar distros)

```bash
flatpak install flathub com.usebottles.bottles
```

If Bottles does not appear in your app menu, restart your session.

### AUR (Arch-based distros, not recommended)

> [!WARNING]
> The Bottles package on AUR is not an official distribution and currently shows many bugs in this setup.
> For stability, use the Flatpak version instead.

```bash
yay -S bottles
```

---

## 2. Create the TouchDesigner Bottle

1. Open Bottles.
2. Create a new bottle.
3. Use these settings:

| Setting | Value |
| --- | --- |
| Name | TouchDesigner |
| Environment | Gaming |
| Runner | soda |
| Directory | Default |

4. Create the bottle and wait for setup to finish.

---

## 3. Install Dependencies

Inside the bottle:

1. Go to **Dependencies**.
2. Install:
	- `allfonts`
	- `d3dx11` (latest version)

---

## 4. Install TouchDesigner

1. Download the Windows installer from Derivative.
2. In Bottles, click **Run Executable**.
3. Select the `.exe` file.
4. Install normally (same process as Windows).

---

## 5. Launch TouchDesigner

1. Open **Programs** in Bottles.
2. Click **Play** on TouchDesigner.

TouchDesigner should now run.

---

## 6. Fix Missing Fonts

Some UI elements may appear blank due to font rendering issues.

### Solution

1. Add `wine_ui_fixes.tox` to your project.
	- [Download `wine_ui_fixes.tox` directly](https://raw.githubusercontent.com/isw3d/TouchDesigner-Linux/main/wine_ui_fixes.tox)
	- Original post: [c0deous on Derivative](https://derivative.ca/community-post/asset/minor-ui-fixes-touchdesigner-wine/73421)
2. Click **Fix Now**.

Fonts will display correctly as long as the `.tox` file is present in the project.

---

## 7. Optional: Flatpak Filesystem Access

If you installed Bottles via Flatpak, opening `.toe` files directly from your system may fail.

Install Flatseal:

```bash
flatpak install flathub com.github.tchx84.Flatseal
```

Then:

1. Open Flatseal.
2. Select **Bottles**.
3. Go to **Filesystem**.
4. Enable **All system files**.

> [!WARNING]
> This disables sandboxing protections for Bottles.

---

## 8. Optional: Desktop Integration

### Desktop shortcut

Inside Bottles, click the **⋮** next to TouchDesigner and select **Add Desktop Entry**.

### File association & icon

1. Associate `.toe` files with TouchDesigner.
2. Assign the TouchDesigner icon (`.png`) to the file type.

The icon is located at:

**Flatpak:**
```
$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/TouchDesigner/icons/TouchDesigner.png
```

**AUR:**
```
$HOME/.local/share/bottles/bottles/TouchDesigner/icons/TouchDesigner.png
```

### `.toe` icon association example

If the association is correctly configured, `.toe` files will display with the TouchDesigner icon.

![Example of `.toe` file with TouchDesigner icon](Screenshots/7.png)

If double-clicking a `.toe` file fails to load the project (path error), you need to update your desktop entry.

> [!IMPORTANT]
> Before running scripts or terminal commands, verify what they do first.
> Check them yourself or ask an AI assistant to explain them.
> Avoid running commands you do not understand or trust.

Run the commands below (copy/paste) to create the launcher script:

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/touchdesigner-launcher.sh << 'EOF'
#!/bin/bash
# Handle Wine path translation for Bottles
INPUT_PATH="$1"

if [ -z "$INPUT_PATH" ]; then
    # Launch TD empty
    flatpak run --command=bottles-cli com.usebottles.bottles run -p TouchDesigner -b TouchDesigner
else
	# Some desktop environments pass local files as file:// URIs.
	if [[ "$INPUT_PATH" == file://* ]]; then
		INPUT_PATH="${INPUT_PATH#file://}"
		INPUT_PATH="${INPUT_PATH//%20/ }"
	fi

    # Launch TD with the file mapped to the Z: drive
	flatpak run --command=bottles-cli com.usebottles.bottles run -p TouchDesigner -b TouchDesigner --args "z:$INPUT_PATH"
fi
EOF
chmod +x ~/.local/bin/touchdesigner-launcher.sh
```

Then run this command to automatically update the TouchDesigner `.desktop` entry:

```bash
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/TouchDesigner.desktop"
[ -f "$DESKTOP_FILE" ] || DESKTOP_FILE="$(grep -lE '(^Name=.*TouchDesigner|bottles-cli.*TouchDesigner)' "$DESKTOP_DIR"/*.desktop 2>/dev/null | head -n1)"
[ -n "$DESKTOP_FILE" ] && sed -i "s|^Exec=.*|Exec=$HOME/.local/bin/touchdesigner-launcher.sh %f|" "$DESKTOP_FILE" && echo "Updated: $DESKTOP_FILE" || echo "TouchDesigner desktop file not found in $DESKTOP_DIR"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
```

## 9. Screenshots

### 1. Bottle setup
![Bottle setup](Screenshots/1.png)

### 2. Dependencies
![Dependencies](Screenshots/2.png)

![Run executable](Screenshots/3.png)

### 3. Launch TouchDesigner
![Launch TouchDesigner](Screenshots/4.png)

### 4. Font missing
![Font fix](Screenshots/5.png)

### 5. Font fix
![Flatseal optional setup](Screenshots/6.png)

---

## 10. Compatibility Status


| Area | Status | Notes |
| --- | --- | --- |
| Launch and runtime | ✅ Working | App launches normally and runs reliably |
| UI rendering | ✅ Working | Correct with `wine_ui_fixes.tox` |
| Real-time visuals | ✅ Working | Live updates and interaction are smooth |
| Inputs / outputs | ✅ Working | External outputs and inputs are functional in tested scenarios |
| NDI | ✅ Working | Confirmed working |
| TD - Bitwig | ✅ Working | Confirmed working |
| Video Device In | ⚠️ Partial | USB Webcams work on first init, but Wine "locks" the device. Replug or TD restart required to reset |
| NVIDIA TOP | ❌ Not working | Background, Flow and Denoise fail to init CUDA/TensorRT in this environment |
| External installs / integrations | ❓ Not fully tested | Third-party installs, Kinect, extra plugins, and advanced external production pipelines still need broader testing |
---

## 11. Notes

- NVIDIA GPUs are highly recommended.
- Wayland is strongly recommended (X11 may cause launch issues or black screen)
- Performance may vary depending on hardware and driver setup.
- Overall, my experience was smoother than on Windows, with better performance and a much cooler-running machine (gaming laptop) due to Linux optimizations.

⚠️ Project Update:
>
>The planned automated install script is currently suspended.
>
>The Linux gaming and compatibility landscape is shifting rapidly with the transition from Wine-GE to UMU and the new Proton 10 standards. To ensure long-term stability and avoid releasing an obsolete tool, I am putting the custom automation on hold until the UMU ecosystem matures for professional creative software.
>
>For now, please stick to the Bottles manual setup for the most reliable experience.
>

Built with care.

Iswad