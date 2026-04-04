## Why this exists

TouchDesigner is not officially supported on Linux.

However, it is actually possible to run it with very good results using Bottles.

This guide provides a complete working setup.

---

## Install Bottles

You can install Bottles using either Flatpak or AUR.

### Flatpak (recommended)

```bash
flatpak install flathub com.usebottles.bottles
```
Restart your session if the app does not appear.

AUR (Arch Linux)
```bash
yay -S bottles
```

Setup TouchDesigner Bottle
Open Bottles
Create a new bottle

Use the following settings:

Name: TouchDesigner
Environment: Gaming
Runner: soda
Directory: Default

Create the bottle and wait for setup to finish.

Install Dependencies

Inside the bottle:

Go to Dependencies
Install the following:
allfonts
d3dx11 (latest version)
Install TouchDesigner
Download the Windows version from Derivative
In Bottles, click Run Executable
Select the .exe
Install normally (like Windows)
Launch TouchDesigner
Go to Programs
Click Play on TouchDesigner

It should now run.

Fix: Missing Fonts

Some UI elements may appear blank.

Solution:
Add wine_ui_fixes.tox
 to your project (thanks to c0deous: link
)
Click Fix Now

Fonts will display correctly as long as the .tox is in your project.

Optional: Flatpak Filesystem Access

If using Flatpak, you may not be able to open .toe files from your system.

Fix this using Flatseal:

flatpak install flathub com.github.tchx84.Flatseal

Then:

Open Flatseal
Select Bottles
Go to Filesystem
Enable All system files

⚠️ This disables sandboxing.

Optional: Desktop Integration
Create a desktop shortcut
Assign TouchDesigner icon (.png)
Associate .toe files
Notes
NVIDIA GPUs recommended
X11 works better than Wayland
Performance may vary

Built with care.
