#!/bin/bash

# Test script for vim mode indicator (integrated into apple icon)
echo "Testing integrated vim mode indicator in the apple icon..."

# Test different vim modes (SketchyVim uses UPPERCASE)
modes=("N" "I" "V" "C" "R" "_")
mode_names=("NORMAL" "INSERT" "VISUAL" "COMMAND" "REPLACE" "OTHER")

echo "Watch the apple icon (🦄) on the left - it should change to vim mode icons!"
echo ""

for i in "${!modes[@]}"; do
    mode="${modes[$i]}"
    name="${mode_names[$i]}"
    
    echo "Testing $name mode ($mode)..."
    
    # Simulate mode change
    sketchybar --trigger svim_update MODE="$mode" CMDLINE=""
    sleep 2
    
    # Test with command line
    if [ "$mode" = "C" ]; then
        echo "Testing command mode with command line..."
        sketchybar --trigger svim_update MODE="$mode" CMDLINE=":w"
        sleep 2
    fi
done

# Test reverting to unicorn
echo "Reverting to unicorn..."
sketchybar --trigger svim_update MODE="" CMDLINE=""
sleep 1

echo ""
echo "Test complete! The apple icon should have changed between:"
echo "🔵 Blue circle (Normal) | ✏️ Green pencil (Insert) | 📌 Orange pin (Visual)"
echo "🖥️ Red terminal (Command) | ↔️ Magenta arrows (Replace) | ➖ Grey minus (Other)"
echo "And then back to 🦄 (Default unicorn)"
echo ""
echo "Priority: Service mode 💀 > Vim modes > Default unicorn 🦄" 