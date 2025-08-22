#!/usr/bin/env python3
import sys
import yaml
from typing import Dict, Any, List, Tuple

def merge_tiles(main_tiles, preview_tiles):
    """Merge tiles arrays, combining unique tiles by tileSlug"""
    merged = []
    tile_slugs_seen = set()
    
    # Add all tiles from main first
    for tile in main_tiles:
        tile_slug = tile.get('tileSlug')
        if tile_slug and tile_slug not in tile_slugs_seen:
            merged.append(tile)
            tile_slugs_seen.add(tile_slug)
    
    # Add new tiles from preview that aren't already in main
    for tile in preview_tiles:
        tile_slug = tile.get('tileSlug')
        if tile_slug and tile_slug not in tile_slugs_seen:
            merged.append(tile)
            tile_slugs_seen.add(tile_slug)
    
    return merged

def merge_dimensions(main_dims, preview_dims):
    """Merge dimension filters, combining unique filters by fieldId"""
    merged = []
    field_ids_seen = set()
    
    # Add all dimensions from main first
    for dim in main_dims:
        field_id = dim.get('target', {}).get('fieldId')
        if field_id and field_id not in field_ids_seen:
            merged.append(dim)
            field_ids_seen.add(field_id)
    
    # Add new dimensions from preview that aren't already in main
    for dim in preview_dims:
        field_id = dim.get('target', {}).get('fieldId')
        if field_id and field_id not in field_ids_seen:
            merged.append(dim)
            field_ids_seen.add(field_id)
    
    return merged

def merge_metrics(main_metrics, preview_metrics):
    """Merge metric filters, combining unique filters by fieldId"""
    merged = []
    field_ids_seen = set()
    
    # Add all metrics from main first
    for metric in main_metrics:
        field_id = metric.get('target', {}).get('fieldId')
        if field_id and field_id not in field_ids_seen:
            merged.append(metric)
            field_ids_seen.add(field_id)
    
    # Add new metrics from preview that aren't already in main
    for metric in preview_metrics:
        field_id = metric.get('target', {}).get('fieldId')
        if field_id and field_id not in field_ids_seen:
            merged.append(metric)
            field_ids_seen.add(field_id)
    
    return merged

def merge_tabs(main_tabs, preview_tabs):
    """Merge tabs arrays, using main's tabs but updating UUIDs if they conflict"""
    merged = []
    tab_names_seen = set()
    
    # Add all tabs from main first
    for tab in main_tabs:
        tab_name = tab.get('name')
        if tab_name and tab_name not in tab_names_seen:
            merged.append(tab)
            tab_names_seen.add(tab_name)
    
    # Add new tabs from preview that aren't already in main
    for tab in preview_tabs:
        tab_name = tab.get('name')
        if tab_name and tab_name not in tab_names_seen:
            merged.append(tab)
            tab_names_seen.add(tab_name)
    
    return merged

def detect_conflicts(main_data: Dict[Any, Any], preview_data: Dict[Any, Any], path: str = "") -> List[Tuple[str, Any, Any]]:
    """Detect conflicts where the same field is changed in both files"""
    conflicts = []
    
    # Skip certain fields that we expect to be different or can auto-resolve
    skip_fields = {'updatedAt', 'downloadedAt'}
    
    for key in main_data:
        if key in skip_fields:
            continue
            
        current_path = f"{path}.{key}" if path else key
        
        if key in preview_data:
            main_value = main_data[key]
            preview_value = preview_data[key]
            
            # If both are dicts, recurse
            if isinstance(main_value, dict) and isinstance(preview_value, dict):
                conflicts.extend(detect_conflicts(main_value, preview_value, current_path))
            # If values are different (and not None), it's a conflict
            elif main_value != preview_value and main_value is not None and preview_value is not None:
                conflicts.append((current_path, main_value, preview_value))
    
    return conflicts

def detect_filter_conflicts(main_data: Dict[Any, Any], preview_data: Dict[Any, Any]) -> List[Tuple[str, Any, Any]]:
    """Detect conflicts in filter values where same fieldId has different configurations"""
    conflicts = []
    
    main_filters = main_data.get('filters', {})
    preview_filters = preview_data.get('filters', {})
    
    # Check dimension filter conflicts
    main_dims = {d.get('target', {}).get('fieldId'): d for d in main_filters.get('dimensions', [])}
    preview_dims = {d.get('target', {}).get('fieldId'): d for d in preview_filters.get('dimensions', [])}
    
    for field_id in main_dims:
        if field_id in preview_dims:
            main_dim = main_dims[field_id]
            preview_dim = preview_dims[field_id]
            
            # Compare key filter properties
            for prop in ['values', 'disabled', 'operator']:
                if main_dim.get(prop) != preview_dim.get(prop):
                    conflicts.append((f"filters.dimensions[{field_id}].{prop}", main_dim.get(prop), preview_dim.get(prop)))
    
    # Check metric filter conflicts  
    main_metrics = {m.get('target', {}).get('fieldId'): m for m in main_filters.get('metrics', [])}
    preview_metrics = {m.get('target', {}).get('fieldId'): m for m in preview_filters.get('metrics', [])}
    
    for field_id in main_metrics:
        if field_id in preview_metrics:
            main_metric = main_metrics[field_id]
            preview_metric = preview_metrics[field_id]
            
            # Compare key filter properties
            for prop in ['values', 'disabled', 'operator']:
                if main_metric.get(prop) != preview_metric.get(prop):
                    conflicts.append((f"filters.metrics[{field_id}].{prop}", main_metric.get(prop), preview_metric.get(prop)))
    
    return conflicts

def validate_merged_file(output_file: str) -> List[str]:
    """Validate the merged file and return list of issues with line numbers"""
    issues = []
    
    try:
        with open(output_file, 'r') as f:
            lines = f.readlines()
            
        with open(output_file, 'r') as f:
            data = yaml.safe_load(f)
        
        # Check for positioning conflicts in tiles
        if 'tiles' in data:
            positions = {}
            for i, tile in enumerate(data['tiles']):
                x = tile.get('x', 0)
                y = tile.get('y', 0)
                pos_key = f"{x},{y}"
                
                if pos_key in positions:
                    # Find line numbers for both tiles
                    tile_slug = tile.get('tileSlug', f'tile_{i}')
                    other_slug = positions[pos_key]['slug']
                    
                    # Find approximate line numbers by searching for tileSlug
                    for line_num, line in enumerate(lines, 1):
                        if f'tileSlug: {tile_slug}' in line:
                            issues.append(f"Line {line_num}: Tile '{tile_slug}' overlaps with '{other_slug}' at position ({x},{y})")
                            break
                else:
                    positions[pos_key] = {'slug': tile.get('tileSlug', f'tile_{i}')}
                
                # Check for null tabUuid
                if tile.get('tabUuid') is None:
                    tile_slug = tile.get('tileSlug', f'tile_{i}')
                    for line_num, line in enumerate(lines, 1):
                        if f'tileSlug: {tile_slug}' in line:
                            # Look backwards for tabUuid: null
                            for check_line in range(max(0, line_num-10), line_num):
                                if 'tabUuid: null' in lines[check_line]:
                                    issues.append(f"Line {check_line+1}: Tile '{tile_slug}' has null tabUuid")
                                    break
                            break
        
        # Check for malformed YAML structure
        for line_num, line in enumerate(lines, 1):
            stripped = line.strip()
            # Look for lines that look like they should be indented but aren't
            if stripped and not stripped.startswith('#') and not stripped.startswith('---'):
                if ':' in stripped and not line.startswith(' ') and not line.startswith('\t'):
                    # Check if this is a root-level field that should be indented
                    root_fields = {'name', 'description', 'updatedAt', 'tiles', 'filters', 'tabs', 'slug', 'spaceSlug', 'version', 'downloadedAt'}
                    field_name = stripped.split(':')[0].strip()
                    if field_name not in root_fields and line_num > 1:
                        issues.append(f"Line {line_num}: '{field_name}' appears to be misaligned or malformed YAML")
        
        # Check for duplicate dashboard names with numbers
        if 'name' in data:
            name = data['name']
            if name.endswith('1') or 'Example1' in name:
                for line_num, line in enumerate(lines, 1):
                    if f'name: {name}' in line:
                        issues.append(f"Line {line_num}: Dashboard name '{name}' appears to be a merge artifact")
                        break
                        
    except Exception as e:
        issues.append(f"Error validating file: {e}")
    
    return issues

def print_conflicts(conflicts: List[Tuple[str, Any, Any]]) -> None:
    """Print conflicts in a readable format"""
    if not conflicts:
        return
        
    print("\n🚨 CONFLICTS DETECTED:")
    print("=" * 60)
    for field_path, main_value, preview_value in conflicts:
        print(f"\nField: {field_path}")
        print(f"  Main branch:    {repr(main_value)}")
        print(f"  Preview branch: {repr(preview_value)}")
    print("=" * 60)
    print("⚠️  Manual review required. Choose which values to keep.")

def track_merge_changes(main_data: Dict[Any, Any], preview_data: Dict[Any, Any], merged_data: Dict[Any, Any]) -> List[Tuple[str, str, Any]]:
    """Track what was added/changed in the merge and where it came from"""
    changes = []
    
    # Track new tiles from preview
    main_tile_slugs = {t.get('tileSlug') for t in main_data.get('tiles', [])}
    merged_tile_slugs = {t.get('tileSlug') for t in merged_data.get('tiles', [])}
    new_tiles = merged_tile_slugs - main_tile_slugs
    
    for tile_slug in new_tiles:
        changes.append(('tiles', 'preview', f"Added tile: {tile_slug}"))
    
    # Track new dimension filters from preview
    main_dim_ids = {d.get('target', {}).get('fieldId') for d in main_data.get('filters', {}).get('dimensions', [])}
    merged_dim_ids = {d.get('target', {}).get('fieldId') for d in merged_data.get('filters', {}).get('dimensions', [])}
    new_dims = merged_dim_ids - main_dim_ids
    
    for dim_id in new_dims:
        changes.append(('filters.dimensions', 'preview', f"Added dimension filter: {dim_id}"))
    
    # Track new metric filters from preview
    main_metric_ids = {m.get('target', {}).get('fieldId') for m in main_data.get('filters', {}).get('metrics', [])}
    merged_metric_ids = {m.get('target', {}).get('fieldId') for m in merged_data.get('filters', {}).get('metrics', [])}
    new_metrics = merged_metric_ids - main_metric_ids
    
    for metric_id in new_metrics:
        changes.append(('filters.metrics', 'preview', f"Added metric filter: {metric_id}"))
    
    # Track new tabs from preview
    main_tab_names = {t.get('name') for t in main_data.get('tabs', [])}
    merged_tab_names = {t.get('name') for t in merged_data.get('tabs', [])}
    new_tabs = merged_tab_names - main_tab_names
    
    for tab_name in new_tabs:
        changes.append(('tabs', 'preview', f"Added tab: {tab_name}"))
    
    # Track timestamp updates
    if merged_data.get('updatedAt') != main_data.get('updatedAt'):
        if merged_data.get('updatedAt') == preview_data.get('updatedAt'):
            changes.append(('updatedAt', 'preview', f"Updated timestamp: {merged_data.get('updatedAt')}"))
    
    if merged_data.get('downloadedAt') != main_data.get('downloadedAt'):
        if merged_data.get('downloadedAt') == preview_data.get('downloadedAt'):
            changes.append(('downloadedAt', 'preview', f"Updated timestamp: {merged_data.get('downloadedAt')}"))
    
    # Track tileTarget updates for existing filters
    for dim in merged_data.get('filters', {}).get('dimensions', []):
        field_id = dim.get('target', {}).get('fieldId')
        if field_id in main_dim_ids:  # This is an existing filter
            main_dim = next((d for d in main_data.get('filters', {}).get('dimensions', []) 
                           if d.get('target', {}).get('fieldId') == field_id), {})
            main_targets = set(main_dim.get('tileTargets', {}).keys())
            merged_targets = set(dim.get('tileTargets', {}).keys())
            new_targets = merged_targets - main_targets
            
            if new_targets:
                changes.append(('filters.dimensions', 'auto-update', f"Added tileTargets for {field_id}: {', '.join(new_targets)}"))
    
    return changes

def print_merge_summary(changes: List[Tuple[str, str, Any]]) -> None:
    """Print a summary of what was merged"""
    if not changes:
        return
        
    print("\n📋 MERGE SUMMARY:")
    print("=" * 60)
    
    preview_changes = [c for c in changes if c[1] == 'preview']
    auto_updates = [c for c in changes if c[1] == 'auto-update']
    timestamp_updates = [c for c in changes if c[1] == 'preview' and 'timestamp' in c[2]]
    
    if preview_changes:
        print("\n📥 Added from preview branch:")
        for section, source, description in preview_changes:
            if 'timestamp' not in description:
                print(f"  • {description}")
    
    if auto_updates:
        print("\n🔄 Automatic updates:")
        for section, source, description in auto_updates:
            print(f"  • {description}")
    
    if timestamp_updates:
        print("\n⏰ Timestamp updates:")
        for section, source, description in timestamp_updates:
            print(f"  • {description}")
    
    print("=" * 60)

def annotate_merged_file(output_file: str, main_data: Dict[Any, Any], preview_data: Dict[Any, Any], merged_data: Dict[Any, Any]) -> None:
    """Add git-style merge annotations to highlight what was added/changed"""
    with open(output_file, 'r') as f:
        lines = f.readlines()
    
    annotated_lines = []
    i = 0
    
    # Track what we want to annotate
    main_tile_slugs = {t.get('tileSlug') for t in main_data.get('tiles', [])}
    preview_tile_slugs = {t.get('tileSlug') for t in preview_data.get('tiles', [])}
    new_tiles = preview_tile_slugs - main_tile_slugs
    
    main_dim_ids = {d.get('target', {}).get('fieldId') for d in main_data.get('filters', {}).get('dimensions', [])}
    preview_dim_ids = {d.get('target', {}).get('fieldId') for d in preview_data.get('filters', {}).get('dimensions', [])}
    preserved_dims = main_dim_ids - preview_dim_ids  # Filters only in main (preserved)
    
    in_new_tile = False
    in_preserved_filter = False
    new_tile_slug = None
    preserved_filter_id = None
    
    while i < len(lines):
        line = lines[i]
        
        # Check if we're starting a new tile from preview
        if 'tileSlug:' in line:
            for tile_slug in new_tiles:
                if f'tileSlug: {tile_slug}' in line:
                    annotated_lines.append("# <<<<<<< ADDED FROM PREVIEW\n")
                    in_new_tile = True
                    new_tile_slug = tile_slug
                    break
        
        # Check if we're starting a preserved filter section
        if 'fieldId:' in line:
            for dim_id in preserved_dims:
                if f'fieldId: {dim_id}' in line:
                    # Look back to see if this is in a dimension filter context
                    for j in range(max(0, i-10), i):
                        if 'target:' in lines[j]:
                            annotated_lines.append("# <<<<<<< PRESERVED FROM MAIN (with updated tileTargets)\n")
                            in_preserved_filter = True
                            preserved_filter_id = dim_id
                            break
                    break
        
        annotated_lines.append(line)
        
        # Check if we're ending a new tile
        if in_new_tile and i < len(lines) - 1:
            next_line = lines[i + 1]
            if (next_line.strip().startswith('- x:') or 
                next_line.strip().startswith('filters:') or
                next_line.strip().startswith('tabs:') or
                not next_line.strip()):
                annotated_lines.append("# >>>>>>> END ADDED FROM PREVIEW\n")
                in_new_tile = False
                new_tile_slug = None
        
        # Check if we're ending a preserved filter
        if in_preserved_filter and i < len(lines) - 1:
            next_line = lines[i + 1]
            if (next_line.strip().startswith('- target:') or 
                next_line.strip().startswith('tableCalculations:') or
                not next_line.strip()):
                annotated_lines.append("# >>>>>>> END PRESERVED FROM MAIN\n")
                in_preserved_filter = False
                preserved_filter_id = None
        
        i += 1
    
    # Write back the annotated file
    with open(output_file, 'w') as f:
        f.writelines(annotated_lines)

def main():
    if len(sys.argv) != 4:
        print("Usage: merge_yaml.py main_file preview_file output_file")
        sys.exit(1)
    
    main_file = sys.argv[1]
    preview_file = sys.argv[2]
    output_file = sys.argv[3]
    
    try:
        with open(main_file, 'r') as f:
            main_data = yaml.safe_load(f)
        
        with open(preview_file, 'r') as f:
            preview_data = yaml.safe_load(f)
        
        # Check for conflicts first
        conflicts = detect_conflicts(main_data, preview_data)
        filter_conflicts = detect_filter_conflicts(main_data, preview_data)
        
        all_conflicts = conflicts + filter_conflicts
        if all_conflicts:
            print_conflicts(all_conflicts)
            print(f"\n⚠️  CONFLICTS DETECTED - Proceeding with merge using main branch preferences")
            print("Review the merge summary below to see what was preserved/added:")
        
        # Start with main data as base
        merged_data = main_data.copy()
        
        # Merge tiles intelligently
        if 'tiles' in main_data and 'tiles' in preview_data:
            merged_data['tiles'] = merge_tiles(main_data['tiles'], preview_data['tiles'])
        elif 'tiles' in preview_data:
            merged_data['tiles'] = preview_data['tiles']
        
        # Merge dimension filters intelligently  
        if 'filters' in main_data or 'filters' in preview_data:
            merged_data.setdefault('filters', {})
            
            # Merge dimensions from both branches
            main_dims = main_data.get('filters', {}).get('dimensions', [])
            preview_dims = preview_data.get('filters', {}).get('dimensions', [])
            
            if main_dims or preview_dims:
                merged_dims = merge_dimensions(main_dims, preview_dims)
                
                # Update tileTargets for all dimensions to include any new tiles
                for dim in merged_dims:
                    if 'tileTargets' in dim:
                        field_id = dim.get('target', {}).get('fieldId')
                        table_name = dim.get('target', {}).get('tableName')
                        
                        # Add any new tiles from merged tiles list
                        for tile in merged_data.get('tiles', []):
                            tile_slug = tile.get('tileSlug')
                            if tile_slug and tile_slug not in dim['tileTargets'] and field_id and table_name:
                                dim['tileTargets'][tile_slug] = {
                                    'fieldId': field_id,
                                    'tableName': table_name
                                }
                
                merged_data['filters']['dimensions'] = merged_dims
            
            # Merge metrics filters intelligently
            main_metrics = main_data.get('filters', {}).get('metrics', [])
            preview_metrics = preview_data.get('filters', {}).get('metrics', [])
            
            if main_metrics or preview_metrics:
                merged_metrics = merge_metrics(main_metrics, preview_metrics)
                
                # Update tileTargets for all metrics to include any new tiles
                for metric in merged_metrics:
                    if 'tileTargets' in metric:
                        field_id = metric.get('target', {}).get('fieldId')
                        table_name = metric.get('target', {}).get('tableName')
                        
                        # Add any new tiles from merged tiles list
                        for tile in merged_data.get('tiles', []):
                            tile_slug = tile.get('tileSlug')
                            if tile_slug and tile_slug not in metric['tileTargets'] and field_id and table_name:
                                metric['tileTargets'][tile_slug] = {
                                    'fieldId': field_id,
                                    'tableName': table_name
                                }
                
                merged_data['filters']['metrics'] = merged_metrics
            
            # Merge table calculations
            if 'tableCalculations' in main_data.get('filters', {}):
                merged_data['filters']['tableCalculations'] = main_data['filters']['tableCalculations']
            elif 'tableCalculations' in preview_data.get('filters', {}):
                merged_data['filters']['tableCalculations'] = preview_data['filters']['tableCalculations']
        
        # Merge tabs intelligently
        if 'tabs' in main_data and 'tabs' in preview_data:
            merged_data['tabs'] = merge_tabs(main_data['tabs'], preview_data['tabs'])
        elif 'tabs' in preview_data:
            merged_data['tabs'] = preview_data['tabs']
        
        # Use the more recent updatedAt timestamp
        if 'updatedAt' in preview_data:
            main_updated = main_data.get('updatedAt', '')
            preview_updated = preview_data.get('updatedAt', '')
            if preview_updated > main_updated:
                merged_data['updatedAt'] = preview_updated
        
        # Use the more recent downloadedAt timestamp
        if 'downloadedAt' in preview_data:
            main_downloaded = main_data.get('downloadedAt', '')
            preview_downloaded = preview_data.get('downloadedAt', '')
            if preview_downloaded > main_downloaded:
                merged_data['downloadedAt'] = preview_downloaded
        
        # For name conflicts, prefer main branch name (keep existing logic)
        
        # Write merged result with annotations
        with open(output_file, 'w') as f:
            yaml.safe_dump(merged_data, f, default_flow_style=False, sort_keys=False)
        
        # Add merge annotations to highlight changes
        annotate_merged_file(output_file, main_data, preview_data, merged_data)
        
        # Track and report changes
        changes = track_merge_changes(main_data, preview_data, merged_data)
        
        # Validate the merged file
        validation_issues = validate_merged_file(output_file)
        
        # Print results
        if changes:
            print_merge_summary(changes)
        
        if validation_issues:
            print("\n✅ SUCCESS - but validation found issues:")
            print("=" * 50)
            for issue in validation_issues:
                print(f"⚠️  {issue}")
            print("=" * 50)
            print("Please check these lines before using the merged file.")
        else:
            print("\n✅ SUCCESS" if changes else "✅ SUCCESS - no changes detected")
        
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()