# TouchDesigner on Linux (via Bottles)

![Screenshot](Screenshots/0.png)

TouchDesigner is not officially supported on Linux, but it can run very well through Bottles (Wayland).

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

### AUR (Arch-based distros)

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
/home/{YOUR_USER}/.var/app/com.usebottles.bottles/data/bottles/bottles/TouchDesigner/icons/TouchDesigner.png
```

**AUR:**
```
/home/{YOUR_USER}/.local/share/bottles/bottles/TouchDesigner/icons/TouchDesigner.png
```

### `.toe` icon association example

If the association is correctly configured, `.toe` files will display with the TouchDesigner icon.

![Example of `.toe` file with TouchDesigner icon](Screenshots/7.png)

---

## 9. Screenshots

### 1. Bottle setup
![Bottle setup](Screenshots/1.png)

### 2. Dependencies
![Dependencies](Screenshots/2.png)

### 3. Run executable
![Run executable](Screenshots/3.png)

### 4. Launch TouchDesigner
![Launch TouchDesigner](Screenshots/4.png)

### 5. Font missing
![Font fix](Screenshots/5.png)

### 6. Font fix
![Flatseal optional setup](Screenshots/6.png)

---

## 10. Compatibility Status

In this setup, TouchDesigner is fully usable and all core features tested so far are working.

| Area | Status | Notes |
| --- | --- | --- |
| Launch and runtime | ✅ Working | App launches normally and runs reliably |
| UI rendering | ✅ Working | Correct with `wine_ui_fixes.tox` |
| Real-time visuals | ✅ Working | Live updates and interaction are smooth |
| Inputs / outputs | ✅ Working | External outputs and inputs are functional in tested scenarios |
| NDI | ✅ Working | Confirmed working |
| NVIDIA TOP | ✅ Working | Confirmed working |
| Features known to fail | ⚠️ None found | No reproducible broken feature in current tests |
| External installs / integrations | ❓ Not fully tested | Third-party installs, extra plugins, and advanced external production pipelines still need broader testing |

> ✅ This setup is stable enough for real-world usage based on current tests.
---

## 11. Notes

- NVIDIA GPUs are highly recommended.
- Wayland is strongly recommended (X11 may cause launch issues or black screen)
- Performance may vary depending on hardware and driver setup.
- Overall, my experience was smoother than on Windows, with better performance (up to +20%) and a much cooler-running machine (up to -20°C) due to Linux optimizations.

Built with care.

Iswad
