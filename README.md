<div align="center">
    <h1>【 raven-dots 】</h1>
    <h3>Hyprland dotfiles with squared windows, Material You theming, and a 3D wallpaper picker</h3>
</div>

<div align="center">
    <h2>• overview •</h2>
    <h3></h3>
</div>

<details open> 
  <summary>What this is/isn't</summary>

  - Personal Wayland dotfiles built around Hyprland and Quickshell.
  - Focuses on squared 90° window geometry, Material You colors synced across GTK, Qt, and terminals, and floating-first window management.
  - Not a base OS installer: install your graphics drivers, audio stack, and base Linux system before running setup.
  
</details>

<details open> 
  <summary>Notable features</summary>
     
  - Squared 90° window corners (`rounding = 0`), 95% active and 88% inactive opacity, and opaque undimmed fullscreen playback for video players and browsers.
  - New windows open floating and centered by default; dragging any window by its titlebar or with `Super + LMB` snaps to halves, quarters, or maximized, shrinks covered 50% sides into corners, swaps slots when dropped onto another window, and keeps floating windows above snapped ones.
  - Hold and drag dock icons to reorder pinned apps or running windows on either side of the separator, with persisted pinned order.
  - 3D coverflow wallpaper picker (`Super + W` to toggle, scroll wheel to browse, double-click or `Enter` to apply) with color filters and crossfaded wallpaper and palette updates.
  - Bundled `kitty`, `fish`, `starship` (` `), and `fastfetch` config that reloads Material You terminal colors on theme changes.
  - Dark and light mode toggle that updates GNOME GSettings, DConf, GTK 3/4, Flatpak overrides, and `xdg-desktop-portal`.
</details>

<div align="center">
    <h2>• installation •</h2>
    <h3></h3>
</div>

<details open> 
  <summary>Fresh installation</summary>

  Clone this repository and run the automated installer:

  ```bash
  git clone git@github.com:xzhrael/raven-dots.git ~/raven-dots
  cd ~/raven-dots
  ./setup install
  ```

  The installer handles:
  1. Distro package manager detection (Arch, Fedora, openSUSE, Gentoo, etc.).
  2. Installing required dependencies (including `fastfetch`, `kitty`, Quickshell, and Hyprland utilities).
  3. Deploying configurations to `~/.config/` and `~/.local/share/`.

</details>

<details> 
  <summary>Updating existing setup</summary>

  To pull the latest commits and update files in-place:

  ```bash
  cd ~/raven-dots
  git pull
  ./setup install-files
  ```

</details>

<div align="center">
    <h2>• keybinds •</h2>
    <h3></h3>
</div>

<details open>
  <summary>Essential shortcuts</summary>

  | Keybind | Action |
  | :--- | :--- |
  | `Super` | Toggle app drawer (application grid) |
  | `Super` + `Tab` | Toggle workspaces overview (10 workspaces) |
  | `Super` + `Return` | Terminal (`kitty`) |
  | `Super` + `E` | File manager (`nautilus`) |
  | `Super` + `B` | Web browser |
  | `Super` + `W` | Toggle 3D coverflow wallpaper picker |
  | `Super` + `Q` | Close focused window |
  | `Super` + `Alt` + `Space` | Toggle window floating/tiling |
  | `Super` + `N` | Right sidebar & quick settings |
  | `Ctrl` + `Super` + `T` | Open 3D coverflow wallpaper picker |
  | `Ctrl` + `Super` + `Shift` + `D` | Toggle dark/light mode |
  | `Super` + `/` | Complete keybind cheatsheet |

</details>

<div align="center">
    <h2>• components •</h2>
    <h3></h3>
</div>

<details>
  <summary>Software stack</summary>

  | Component | Software | Role |
  | :--- | :--- | :--- |
  | Compositor | Hyprland | Window manager & Wayland compositor |
  | Shell & UI | Quickshell | Status bar, dock, sidebars, and control center |
  | Wallpaper Picker | hyprquickpaper | 3D Coverflow wallpaper selector with color filters |
  | Terminal | kitty | GPU-accelerated terminal with dynamic color reload |
  | Shell | fish | Interactive shell with autosuggestions & aliases |
  | Prompt | starship | Minimal prompt (` `) |
  | Telemetry | fastfetch | Fast system info display with custom ASCII branding |
  | Theming | matugen | Dynamic Material You palette generation from wallpaper |

</details>

<div align="center">
    <h2>• credits & foundation •</h2>
    <h3></h3>
</div>

- **Foundation**: Based on the foundation of end-4/dots-hyprland under the GNU General Public License v3.0.
- **Wallpaper Coverflow**: Inspired by 43PR.
- **License**: GNU General Public License v3.0 - see [LICENSE](LICENSE) for details.

<div align="center">
    <sub>raven-dots • personal wayland environment</sub>
</div>
