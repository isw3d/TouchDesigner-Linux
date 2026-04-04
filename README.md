# TouchDesigner-Linux
Run TouchDesigner on Linux with Bottles. Includes full setup, dependencies, and a working fix for missing fonts.


# TouchDesigner-Linux

Run TouchDesigner on Linux with Bottles. Includes full setup, dependencies, and a working fix for missing fonts.

---

## Overview

This guide explains how to run TouchDesigner on Linux using Bottles.  
It covers the full setup process, required dependencies, and fixes for common issues.

---

## Why this exists

TouchDesigner is not officially supported on Linux, and running it through Wine can be unstable or incomplete.

This guide provides a working setup with:
- Bottles configuration
- Required dependencies
- A fix for missing fonts (common issue)

---

## Requirements

- Linux system (tested on your distro)
- Bottles installed
- A compatible GPU (NVIDIA recommended)
- TouchDesigner installer (.exe)

---

## Installation

### 1. Install Bottles

Install Bottles from Flatpak:

```bash
flatpak install flathub com.usebottles.bottles
