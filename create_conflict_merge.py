#!/usr/bin/env python3
"""
Script to create merged YAML files with conflict markers showing all differences
between main and preview branches, not just actual conflicts.
"""

import os
import sys
import yaml
from pathlib import Path

def load_yaml_safe(file_path):
    """Load YAML file safely, preserving order and structure"""
    try:
        with open(file_path, 'r') as f:
            return yaml.safe_load(f), f.read()
    except FileNotFoundError:
        return None, None
    except yaml.YAMLError as e:
        print(f"Error parsing YAML in {file_path}: {e}")
        return None, None

def create_conflict_markers(main_content, preview_content, main_data, preview_data):
    """Create a merged file with conflict markers for all differences"""
    
    # If one file doesn't exist, show the whole file as a conflict
    if main_content is None:
        return f"<<<<<<< main\n=======\n{preview_content}\n>>>>>>> preview\n"
    if preview_content is None:
        return f"<<<<<<< main\n{main_content}\n=======\n>>>>>>> preview\n"
    
    # For now, do a simple line-by-line comparison
    main_lines = main_content.strip().split('\n')
    preview_lines = preview_content.strip().split('\n')
    
    result = []
    
    # Simple approach: if files are different, show key differences with markers
    if main_data != preview_data:
        # Compare specific fields and create conflict markers
        merged_data = {}
        
        # Handle name field
        if main_data.get('name') != preview_data.get('name'):
            result.append("<<<<<<< main")
            result.append(f"name: {main_data.get('name')}")
            result.append("=======")
            result.append(f"name: {preview_data.get('name')}")
            result.append(">>>>>>> preview")
        else:
            result.append(f"name: {main_data.get('name')}")
        
        # Handle other fields that are the same
        for key in ['updatedAt', 'description']:
            if key in preview_data:
                result.append(f"{key}: {repr(preview_data[key])}")
        
        # Handle tiles - show differences
        main_tiles = main_data.get('tiles', [])
        preview_tiles = preview_data.get('tiles', [])
        
        result.append("tiles:")
        
        # Find common tiles and differences
        common_tiles = []
        main_only_tiles = []
        preview_only_tiles = []
        
        for tile in main_tiles:
            if tile in preview_tiles:
                common_tiles.append(tile)
            else:
                main_only_tiles.append(tile)
        
        for tile in preview_tiles:
            if tile not in main_tiles:
                preview_only_tiles.append(tile)
        
        # Add common tiles
        for tile in common_tiles:
            result.extend([f"  - {yaml.dump(tile, default_flow_style=False).strip()}"])
        
        # Add main-only tiles with conflict markers
        if main_only_tiles:
            result.append("<<<<<<< main")
            for tile in main_only_tiles:
                tile_yaml = yaml.dump(tile, default_flow_style=False, indent=2).strip()
                for line in tile_yaml.split('\n'):
                    result.append(f"  {line}")
            result.append("=======")
            result.append(">>>>>>> preview")
        
        # Add preview-only tiles with conflict markers  
        if preview_only_tiles:
            result.append("<<<<<<< main")
            result.append("=======")
            for tile in preview_only_tiles:
                tile_yaml = yaml.dump(tile, default_flow_style=False, indent=2).strip()
                for line in tile_yaml.split('\n'):
                    result.append(f"  {line}")
            result.append(">>>>>>> preview")
        
        # Handle filters - show differences
        main_filters = main_data.get('filters', {})
        preview_filters = preview_data.get('filters', {})
        
        if main_filters != preview_filters:
            result.append("filters:")
            result.append("  metrics: []")
            result.append("  dimensions:")
            
            # Add common dimensions
            main_dims = main_filters.get('dimensions', [])
            preview_dims = preview_filters.get('dimensions', [])
            
            common_dims = [dim for dim in main_dims if dim in preview_dims]
            main_only_dims = [dim for dim in main_dims if dim not in preview_dims]
            preview_only_dims = [dim for dim in preview_dims if dim not in main_dims]
            
            for dim in common_dims:
                dim_yaml = yaml.dump(dim, default_flow_style=False, indent=4).strip()
                for line in dim_yaml.split('\n'):
                    result.append(f"    {line}")
            
            if main_only_dims or preview_only_dims:
                result.append("<<<<<<< main")
                for dim in main_only_dims:
                    dim_yaml = yaml.dump(dim, default_flow_style=False, indent=4).strip()
                    for line in dim_yaml.split('\n'):
                        result.append(f"    {line}")
                result.append("=======")
                for dim in preview_only_dims:
                    dim_yaml = yaml.dump(dim, default_flow_style=False, indent=4).strip()
                    for line in dim_yaml.split('\n'):
                        result.append(f"    {line}")
                result.append(">>>>>>> preview")
            
            result.append("  tableCalculations: []")
        
        # Add remaining fields
        for key in ['tabs', 'slug', 'spaceSlug', 'version', 'downloadedAt']:
            if key in preview_data:
                if isinstance(preview_data[key], (list, dict)):
                    result.append(f"{key}:")
                    yaml_content = yaml.dump(preview_data[key], default_flow_style=False, indent=2)
                    for line in yaml_content.strip().split('\n'):
                        result.append(f"  {line}")
                else:
                    result.append(f"{key}: {repr(preview_data[key])}")
        
        return '\n'.join(result) + '\n'
    
    else:
        # Files are identical
        return main_content

def process_directory(main_dir, preview_dir, output_dir):
    """Process all YAML files in the directories"""
    
    main_path = Path(main_dir)
    preview_path = Path(preview_dir)
    output_path = Path(output_dir)
    
    # Create output directory
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Find all YAML files
    yaml_files = set()
    
    if main_path.exists():
        yaml_files.update(main_path.rglob("*.yml"))
        yaml_files.update(main_path.rglob("*.yaml"))
    
    if preview_path.exists():
        yaml_files.update(preview_path.rglob("*.yml"))
        yaml_files.update(preview_path.rglob("*.yaml"))
    
    # Convert to relative paths
    yaml_files = {f.relative_to(f.parents[len(f.parents)-3]) for f in yaml_files}
    
    for yaml_file in yaml_files:
        main_file = main_path / yaml_file.name
        preview_file = preview_path / yaml_file.name
        output_file = output_path / yaml_file.name
        
        print(f"Processing {yaml_file.name}...")
        
        main_data, main_content = load_yaml_safe(main_file)
        preview_data, preview_content = load_yaml_safe(preview_file)
        
        merged_content = create_conflict_markers(main_content, preview_content, main_data, preview_data)
        
        # Create output subdirectory if needed
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_file, 'w') as f:
            f.write(merged_content)
        
        print(f"Created merged file: {output_file}")

def main():
    if len(sys.argv) != 4:
        print("Usage: python create_conflict_merge.py <main_dir> <preview_dir> <output_dir>")
        print("Example: python create_conflict_merge.py lightdash/main lightdash/preview lightdash/merged")
        sys.exit(1)
    
    main_dir = sys.argv[1]
    preview_dir = sys.argv[2] 
    output_dir = sys.argv[3]
    
    process_directory(main_dir, preview_dir, output_dir)
    print("Merge complete!")

if __name__ == "__main__":
    main()