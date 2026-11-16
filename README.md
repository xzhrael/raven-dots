<div align="center">
    <h1>【 raven-dots 】</h1>
    <h3>A sharp geometric & dynamic Wayland desktop for Hyprland</h3>
</div>

<div align="center">
    <h2>• overview •</h2>
    <h3></h3>
</div>

<details open> 
  <summary>What this is/isn't</summary>

  - **Technically**: Personal Wayland dotfiles configured for Hyprland.
  - **Realistically**: A daily-driver desktop environment focused on sharp 90° geometry, dynamic Material You color schemes, an interactive 3D Coverflow wallpaper selector, and a fully synced terminal environment.
  - **NOT a base system installer**: You still need working graphics drivers, audio stack, and a base Linux installation before running setup.
  
</details>

<details open> 
  <summary>Notable features</summary>
     
  - **Sharp 90° Geometry**: Pure squared window corners (`rounding = 0`) across all windows for a clean architectural aesthetic.
  - **Calibrated Opacity**: 95% active opacity, 88% inactive opacity for natural visual depth, and automatic 100% solid fullscreen apps (videos, streaming, games).
  - **3D Coverflow Wallpaper Selector**: Single-instance toggle (`Super + W` to open; `Super + W` or `Esc` to close) with mouse wheel glide, double-click application, and square solid-color category chips with active checkmark indicators.
  - **Terminal Suite & Fastfetch**: Built-in `kitty` terminal paired with `fish` shell, custom `starship` prompt (` `), and customized `fastfetch` displaying personalized ASCII art and system telemetry on launch.
  - **Universal Dark/Light Sync**: Status bar toggle that instantly synchronizes GNOME GSettings, DConf, GTK-3, GTK-4 Libadwaita, Flatpak sandboxes, and XDG Desktop Portals.
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
  | `Super` + `Return` | Terminal (`kitty`) |
  | `Super` + `E` | File manager (`nautilus`) |
  | `Super` + `B` | Web browser |
  | `Super` + `W` | **Toggle 3D Coverflow Wallpaper Picker** |
  | `Super` + `Q` | Close focused window |
  | `Super` + `Space` | Toggle window tiling / floating |
  | `Super` + `N` | Right sidebar & quick settings |
  | `Super` + `Tab` | Workspaces overview |
  | `Ctrl` + `Super` + `T` | Regenerate dynamic palette (Matugen) |
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
