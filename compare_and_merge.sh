#!/bin/bash

# Script to compare files between main and preview directories and generate merge conflict files

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    # Default values
    MAIN_DIR="lightdash/main"
    PREVIEW_DIR="lightdash/preview"
elif [[ $# -eq 2 ]]; then
    # User provided both directories
    MAIN_DIR="$1"
    PREVIEW_DIR="$2"
else
    echo "Usage: $0 [main_dir preview_dir]"
    echo "Examples:"
    echo "  $0                                    # Uses default: lightdash/main lightdash/preview"
    echo "  $0 lightdash/main lightdash/preview   # Specify both directories"
    exit 1
fi

MERGED_DIR="lightdash/merged"
CONFLICTS_FILE="$MERGED_DIR/CONFLICTS.md"

# Validate directories exist
if [[ ! -d "$MAIN_DIR" ]]; then
    echo "Error: Main directory '$MAIN_DIR' does not exist"
    exit 1
fi

if [[ ! -d "$PREVIEW_DIR" ]]; then
    echo "Error: Preview directory '$PREVIEW_DIR' does not exist"
    exit 1
fi

# Create merged directory if it doesn't exist
mkdir -p "$MERGED_DIR"
mkdir -p "$MERGED_DIR/charts"
mkdir -p "$MERGED_DIR/dashboards"

# Initialize conflicts tracking file
cat > "$CONFLICTS_FILE" << 'EOF'
# Merge Conflicts Resolution Status

This file tracks the resolution status of merge conflicts between main and preview branches.

## How to resolve conflicts:
1. Open files marked with `🚨 NEEDS RESOLUTION` 
2. Look for conflict markers: `<<<<<<<`, `=======`, `>>>>>>>`
3. Choose the correct version or manually merge
4. Remove all conflict markers
5. Mark as resolved in this file by changing status to `✅ RESOLVED`

## Files Status:

EOF

echo "Comparing files between $MAIN_DIR and $PREVIEW_DIR..."
echo "Generating merge conflict files in $MERGED_DIR..."
echo

# Function to normalize file by removing timestamp fields
normalize_file() {
    local input_file=$1
    local output_file=$2
    # Remove lines containing downloadedAt and updatedAt timestamps
    grep -v -E '^(downloadedAt|updatedAt):' "$input_file" > "$output_file"
}

# Function to create contextual merge with conflict markers only around changed sections
create_contextual_merge() {
    local main_file=$1
    local preview_file=$2
    local output_file=$3
    
    # Try git merge-file first for intelligent 3-way merging
    if command -v git >/dev/null 2>&1; then
        local temp_base="/tmp/base_$(basename "$main_file")"
        local temp_main="/tmp/main_$(basename "$main_file")"
        local temp_preview="/tmp/preview_$(basename "$main_file")"
        
        # Create normalized versions without timestamps and names for better merging
        grep -v -E '^(name|downloadedAt|updatedAt):' "$main_file" > "$temp_main"
        grep -v -E '^(name|downloadedAt|updatedAt):' "$preview_file" > "$temp_preview"
        
        # Use the main file as the common base
        cp "$temp_main" "$temp_base"
        
        # Try git merge-file with the normalized files
        if git merge-file --stdout "$temp_main" "$temp_base" "$temp_preview" > "/tmp/merged_content" 2>/dev/null || true; then
            # Extract key fields for proper handling
            local main_name=$(grep '^name:' "$main_file" 2>/dev/null || echo "")
            local preview_name=$(grep '^name:' "$preview_file" 2>/dev/null || echo "")
            local main_updated=$(grep '^updatedAt:' "$main_file" 2>/dev/null || echo "updatedAt: \"\"")
            local preview_updated=$(grep '^updatedAt:' "$preview_file" 2>/dev/null || echo "updatedAt: \"\"")
            local main_downloaded=$(grep '^downloadedAt:' "$main_file" 2>/dev/null || echo "downloadedAt: \"\"")
            local preview_downloaded=$(grep '^downloadedAt:' "$preview_file" 2>/dev/null || echo "downloadedAt: \"\"")
            
            # Build the final output with proper conflict markers
            local temp_output="/tmp/output_$(basename "$main_file")"
            {
                # Handle name field conflict
                if [[ "$main_name" != "$preview_name" && -n "$main_name" && -n "$preview_name" ]]; then
                    echo "<<<<<<< main"
                    echo "$main_name"
                    echo "======="
                    echo "$preview_name"
                    echo ">>>>>>> preview"
                elif [[ -n "$main_name" ]]; then
                    echo "$main_name"
                elif [[ -n "$preview_name" ]]; then
                    echo "$preview_name"
                fi
                
                # Description will be included in the merged content below, no need to add it here
                
                # Choose the newer timestamp automatically
                if [[ "$main_updated" > "$preview_updated" ]]; then
                    echo "$main_updated"
                else
                    echo "$preview_updated"
                fi
                
                # Add the merged content (everything except metadata)
                cat "/tmp/merged_content"
                
                # Choose the newer downloaded timestamp automatically
                if [[ "$main_downloaded" > "$preview_downloaded" ]]; then
                    echo "$main_downloaded"
                else
                    echo "$preview_downloaded"
                fi
            } > "$temp_output"
            
            # Replace git's generic markers with our custom ones in the main content
            sed -i.bak 's/^<<<<<<< .*/<<<<<<< main/' "$temp_output"
            sed -i.bak 's/^>>>>>>> .*/>>>>>>> preview/' "$temp_output"
            
            mv "$temp_output" "$output_file"
            rm -f "$output_file.bak" "$temp_base" "$temp_main" "$temp_preview" "/tmp/merged_content"
            return 0
        fi
        
        rm -f "$temp_base" "$temp_main" "$temp_preview"
    fi
}

# Function to intelligently merge YAML dashboard files
merge_dashboard_yaml() {
    local main_file=$1
    local preview_file=$2
    local output_file=$3
    
    # Use separate Python script to merge dashboard YAML files intelligently
    python3 merge_yaml.py "$main_file" "$preview_file" "$output_file"
}

# Function to create merge conflict file
generate_merge_file() {
    local subdir=$1
    local filename=$2
    local main_file="$MAIN_DIR/$subdir/$filename"
    local preview_file="$PREVIEW_DIR/$subdir/$filename"
    local merged_file="$MERGED_DIR/$subdir/$filename"
    local main_normalized="/tmp/main_${filename}"
    local preview_normalized="/tmp/preview_${filename}"
    
    echo "Processing $subdir/$filename..."
    
    if [[ -f "$main_file" && -f "$preview_file" ]]; then
        # Both files exist - normalize and check if they differ (ignoring timestamps)
        normalize_file "$main_file" "$main_normalized"
        normalize_file "$preview_file" "$preview_normalized"
        
        if diff -q "$main_normalized" "$preview_normalized" > /dev/null; then
            echo "  ✅ No conflicts - files identical (ignoring timestamps)"
            cp "$main_file" "$merged_file"
            echo "- **$subdir/$filename**: ✅ NO CONFLICTS (identical except timestamps)" >> "$CONFLICTS_FILE"
        else
            # Try intelligent YAML merging for dashboard files
            if [[ "$subdir" == "dashboards" && "$filename" == *.yml ]]; then
                echo "  🔄 Attempting intelligent YAML merge for dashboard..."
                if merge_result=$(merge_dashboard_yaml "$main_file" "$preview_file" "$merged_file" 2>&1); then
                    if [[ "$merge_result" == "SUCCESS"* ]]; then
                        echo "  ✅ Successfully merged dashboard YAML"
                        echo "- **$subdir/$filename**: ✅ AUTO-MERGED (intelligent YAML merge)" >> "$CONFLICTS_FILE"
                        rm -f "$main_normalized" "$preview_normalized"
                        return
                    else
                        echo "  ⚠️  YAML merge failed: $merge_result"
                    fi
                else
                    echo "  ⚠️  YAML merge failed, falling back to conflict markers"
                fi
            fi
            
            echo "  🚨 CONFLICTS FOUND - creating merge file with context"
            # Always use the contextual merge function for conflicts
            create_contextual_merge "$main_file" "$preview_file" "$merged_file"
            
            echo "- **$subdir/$filename**: 🚨 NEEDS RESOLUTION" >> "$CONFLICTS_FILE"
        fi
        
        # Clean up temp files
        rm -f "$main_normalized" "$preview_normalized"
        
    elif [[ -f "$main_file" && ! -f "$preview_file" ]]; then
        # Only in main
        echo "  📁 File only in main - copying"
        cp "$main_file" "$merged_file"
        echo "- **$subdir/$filename**: ✅ MAIN ONLY (copied from main)" >> "$CONFLICTS_FILE"
    elif [[ ! -f "$main_file" && -f "$preview_file" ]]; then
        # Only in preview  
        echo "  📁 File only in preview - copying"
        cp "$preview_file" "$merged_file"
        echo "- **$subdir/$filename**: ✅ PREVIEW ONLY (copied from preview)" >> "$CONFLICTS_FILE"
    fi
}

# Get all unique filenames from both directories
all_chart_files=$(find "$MAIN_DIR/charts" "$PREVIEW_DIR/charts" -name "*.yml" 2>/dev/null | xargs -n1 basename | sort -u)
all_dashboard_files=$(find "$MAIN_DIR/dashboards" "$PREVIEW_DIR/dashboards" -name "*.yml" 2>/dev/null | xargs -n1 basename | sort -u)

echo "=== Processing Charts ==="
for file in $all_chart_files; do
    generate_merge_file "charts" "$file"
done

echo
echo "=== Processing Dashboards ==="
for file in $all_dashboard_files; do
    generate_merge_file "dashboards" "$file"
done

# Calculate summary counts
total_files=$(echo $all_chart_files $all_dashboard_files | wc -w)
needs_resolution=$(grep -c "^\- \*\*.*🚨 NEEDS RESOLUTION" "$CONFLICTS_FILE")
no_conflicts=$(grep -c "^\- \*\*.*✅" "$CONFLICTS_FILE")

# Add summary to conflicts file
cat >> "$CONFLICTS_FILE" << EOF

## Summary:
- **Total files processed**: $total_files
- **Files needing resolution**: $needs_resolution
- **Files with no conflicts**: $no_conflicts

## Next Steps:
1. Review files marked with 🚨 NEEDS RESOLUTION
2. Use your preferred merge tool or editor to resolve conflicts
3. Update this file to mark resolved conflicts as ✅ RESOLVED

Generated on: $(date)
EOF

echo
echo "=== Summary ==="
echo "📁 Generated merge files in: $MERGED_DIR"
echo "📋 Conflicts tracking file: $CONFLICTS_FILE"
echo
echo "Files needing resolution:"
grep "🚨 NEEDS RESOLUTION" "$CONFLICTS_FILE" || echo "  None! 🎉"
echo
echo "Open $CONFLICTS_FILE to see full status and resolution instructions."