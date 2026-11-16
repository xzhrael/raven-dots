#!/usr/bin/env python3
import os
import json
import colorsys
from collections import defaultdict
from PIL import Image

def classify_wallpaper_colors():
    thumbs_dir = os.path.expanduser("~/.cache/quickshell/thumbs")
    best_dir = os.path.expanduser("~/Pictures/Best")
    output_json = os.path.expanduser("~/.cache/quickshell/wallpaper_colors.json")
    
    mapping = {}
    target_files = []
    if os.path.exists(best_dir):
        for f in os.listdir(best_dir):
            if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.gif', '.mp4', '.mkv', '.webm', '.mov')):
                target_files.append(f)
                
    for fname in target_files:
        thumb_path = os.path.join(thumbs_dir, fname)
        img_path = os.path.join(best_dir, fname)
        read_path = thumb_path if os.path.exists(thumb_path) and not thumb_path.endswith(('.gif', '.mp4', '.mkv', '.webm', '.mov')) else img_path
        
        if fname.lower().endswith(('.mp4', '.mkv', '.webm', '.mov')):
            preview_gif = os.path.join(thumbs_dir, fname + ".preview.gif")
            if os.path.exists(preview_gif):
                read_path = preview_gif
            else:
                mapping[fname] = "dark"
                continue
                
        try:
            with Image.open(read_path) as img:
                img = img.convert("RGB").resize((48, 48))
                pixels = list(img.getdata())
                
                color_buckets = defaultdict(float)
                total_weight = 0.0
                dark_weight = 0.0
                light_weight = 0.0
                
                for r, g, b in pixels:
                    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
                    weight = (s ** 1.5) * (v ** 0.5)
                    
                    if v < 0.12:
                        dark_weight += (0.12 - v) * 4
                    elif s < 0.14:
                        if v > 0.72:
                            light_weight += (v - 0.72) * 2
                        elif v < 0.35:
                            dark_weight += (0.35 - v) * 2
                    
                    if s >= 0.18 and v >= 0.10:
                        hue_deg = h * 360
                        if hue_deg >= 350 or hue_deg < 18:
                            cname = "red"
                        elif hue_deg < 45:
                            cname = "orange"
                        elif hue_deg < 70:
                            cname = "yellow"
                        elif hue_deg < 165:
                            cname = "green"
                        elif hue_deg < 255:
                            cname = "blue"
                        elif hue_deg < 310:
                            cname = "purple"
                        else:
                            cname = "pink"
                        color_buckets[cname] += weight
                        total_weight += weight
                
                if total_weight > 40:
                    best_color = max(color_buckets.items(), key=lambda x: x[1])[0]
                    cat = best_color
                else:
                    cat = "dark" if dark_weight >= light_weight else "light"
                mapping[fname] = cat
        except Exception:
            mapping[fname] = "dark"
            
    os.makedirs(os.path.dirname(output_json), exist_ok=True)
    with open(output_json, "w") as f:
        json.dump(mapping, f, indent=2)
    print(f"Successfully classified {len(mapping)} wallpapers into {output_json}")

if __name__ == "__main__":
    classify_wallpaper_colors()
