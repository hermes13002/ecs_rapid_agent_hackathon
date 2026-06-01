import os

# Create directory
os.makedirs("assets/icons", exist_ok=True)

# Define SVGs
# We will draw simple line representations for 24x24 icons
svgs = {
    "resistor": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M2 12h5l2.5-5 5 10 5-10 2.5 5h2" />
</svg>''',
    "capacitor": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M4 12h6" />
  <path d="M10 6v12" />
  <path d="M14 6v12" />
  <path d="M14 12h6" />
</svg>''',
    "inductor": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M3 12h3" />
  <path d="M6 12a3 3 0 0 1 6 0 3 3 0 0 1 6 0" />
  <path d="M18 12h3" />
</svg>''',
    "diode": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M2 12h7" />
  <path d="M9 7v10l8-5-8-5z" />
  <path d="M17 7v10" />
  <path d="M17 12h5" />
</svg>''',
    "led": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M2 14h7" />
  <path d="M9 9v10l8-5-8-5z" />
  <path d="M17 9v10" />
  <path d="M17 14h5" />
  <path d="M12 5l-2-3" />
  <path d="M16 5l-2-3" />
</svg>''',
    "junction": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor">
  <circle cx="12" cy="12" r="3" />
</svg>''',
    "npn": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M4 12h4" />
  <path d="M8 7v10" />
  <path d="M8 10l6-6v4" />
  <path d="M14 4h-4" />
  <path d="M8 14l6 6v-4" />
  <path d="M14 20h-4" />
  <path d="M14 4v0" />
  <path d="M14 20l3-3M17 17l-3 0M17 17l0 3" />
</svg>''',
    "pnp": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M4 12h4" />
  <path d="M8 7v10" />
  <path d="M8 10l6-6v4" />
  <path d="M14 4h-4" />
  <path d="M14 4l-3 3M11 7l3 0M11 7l0 -3" />
  <path d="M8 14l6 6v-4" />
  <path d="M14 20h-4" />
</svg>''',
    "voltage": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 2v4" />
  <circle cx="12" cy="12" r="6" />
  <path d="M12 18v4" />
  <path d="M12 8v3" />
  <path d="M10.5 9.5h3" />
  <path d="M10.5 15h3" />
</svg>''',
    "current": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 2v4" />
  <circle cx="12" cy="12" r="6" />
  <path d="M12 18v4" />
  <path d="M12 9v6" />
  <path d="M10 10l2-2 2 2" />
</svg>''',
    "ground": '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 4v8" />
  <path d="M6 12h12" />
  <path d="M8 16h8" />
  <path d="M10 20h4" />
</svg>'''
}

for name, content in svgs.items():
    with open(f"assets/icons/{name}.svg", "w") as f:
        f.write(content)

print(f"Generated {len(svgs)} SVG icons in assets/icons/")
