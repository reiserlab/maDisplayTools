# Web Tools - PanelDisplayTools

Web-based tools for configuring and editing display patterns for modular arena systems.

## Directory Structure

```
web/
├── index.html                # Main landing page
├── g6_panel_editor.html      # G6 Panel Pattern Editor (8×8 pixel patterns)
├── experiment_designer.html  # Experiment Designer
├── arena_editor.html         # Arena layout configurator (coming soon)
├── g41_pattern_editor.html   # G4.1 pattern editor (coming soon)
└── g6_pattern_editor.html    # G6 pattern editor - multi-panel (coming soon)
```

All tools are single-page HTML files in the web/ directory for simplicity.

## Tools

### Landing Page (`index.html`)
Main entry point with a modern dark theme interface that provides links to all available web tools.
Features:
- Dark theme with green accents matching the G6 editor aesthetic
- Card-based layout with hover effects
- Status indicators (Ready/Coming Soon)
- Responsive design

### G6 Panel Pattern Editor (`g6_panel_editor.html`) ✅ Ready
Create and edit 8×8 pixel patterns for G6 panels with:
- Real-time preview
- Draw and erase modes
- Multiple modes: GS2, GS16, 4-Char, LED Map Reference
- Pattern export capabilities
- Modern dark theme UI
- Version 6 (last updated 2025-01-12)

### Experiment Designer (`experiment_designer.html`) 🚧 Coming Soon
Design and configure experiments with visual stimuli sequences and parameter management.

### Arena Layout Editor (`arena_editor.html`) 🚧 Coming Soon
Tool for configuring arena layouts including:
- Panel rows and columns
- Pixels per panel
- Geometry type (cylinder, flat, etc.)
- Export arena configuration files (JSON/YAML)

### G4.1 Pattern Editor (`g41_pattern_editor.html`) 🚧 Coming Soon
Design patterns for G4.1 display systems with support for multiple panel configurations.

### G6 Pattern Editor (`g6_pattern_editor.html`) 🚧 Coming Soon
Advanced pattern editor for G6 display systems with multi-panel support and animation tools.

## Usage

Open `index.html` in a web browser to access all tools locally.

## Design System

All tools use a consistent dark theme design:
- **Background**: `#0f1419`
- **Surface**: `#1a1f26`
- **Border**: `#2d3640`
- **Text**: `#e6edf3`
- **Accent**: `#00e676` (green)
- **Fonts**: JetBrains Mono (headings), IBM Plex Mono (body)

## Development Notes

- All web tools are standalone single-page HTML files (no build process required)
- Vanilla JavaScript is preferred for simplicity
- Web outputs must match MATLAB outputs exactly
- Keep dependencies minimal or use CDN links
- Consistent dark theme across all tools
- Mobile-responsive design

## GitHub Pages Deployment

These tools can be easily deployed using GitHub Pages:

1. Push the web/ directory to your GitHub repository
2. Go to Settings → Pages
3. Set source to deploy from the main branch, `/web` folder
4. Your tools will be available at: `https://reiserlab.github.io/maDisplayTools/`

The tools will work directly since they're all client-side HTML/CSS/JavaScript with no server requirements.

## Testing

All tools can be tested locally by opening the HTML files directly in a web browser. No server setup is required for basic functionality.
