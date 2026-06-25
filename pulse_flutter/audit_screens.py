import os
import re

SCREENS_DIR = r"E:\Niosmess V2\pulse_flutter\lib\screens"

def check_files():
    results = {
        "hardcoded_strings": [],
        "async_context": [],
        "inefficient_listview": [],
        "heavy_build": [],
        "setState_abuse": [],
        "unoptimized_images": []
    }
    
    for filename in os.listdir(SCREENS_DIR):
        if not filename.endswith(".dart"): continue
        path = os.path.join(SCREENS_DIR, filename)
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
            lines = content.split('\n')
            
            # Check hardcoded strings in Text()
            for i, line in enumerate(lines):
                if re.search(r"Text\(\s*['\"][A-ZА-Я]", line) and not "context.l10n" in line and not "Text(''" in line:
                    results["hardcoded_strings"].append(f"{filename}:{i+1} -> {line.strip()}")
                    
            # Check BuildContext across async gaps (naive)
            blocks = content.split('async')
            for block in blocks[1:]:
                if 'await ' in block and ('Navigator.of(context)' in block or 'ScaffoldMessenger.of(context)' in block) and 'mounted' not in block[:block.find('Navigator')]:
                    if filename not in results["async_context"]:
                        results["async_context"].append(filename)
                    
            # Check inefficient ListViews (using ListView(children: ...) instead of builder for mapped data)
            if "ListView(" in content and "children:" in content and "map(" in content:
                results["inefficient_listview"].append(filename)
                
            # setState inside loops or large blocks
            if content.count("setState(") > 5:
                results["setState_abuse"].append(filename)
                
            # Unoptimized images
            if "Image.network" in content and "cacheWidth" not in content:
                results["unoptimized_images"].append(filename)

    print("=== STATIC ANALYSIS RESULTS ===")
    print(f"Hardcoded Strings (potential): {len(results['hardcoded_strings'])} occurrences in {len(set(x.split(':')[0] for x in results['hardcoded_strings']))} files")
    for s in results["hardcoded_strings"]: print("  - " + s)
    
    print(f"\nPotential BuildContext async gap issues (no mounted check):")
    for s in set(results["async_context"]): print("  - " + s)
    
    print(f"\nInefficient ListViews (using ListView instead of ListView.builder for mapped data):")
    for s in set(results["inefficient_listview"]): print("  - " + s)

    print(f"\nFiles with excessive setState (potential performance issues > 5):")
    for s in set(results["setState_abuse"]): print("  - " + s)

    print(f"\nFiles with unoptimized network images (missing cache dimensions):")
    for s in set(results["unoptimized_images"]): print("  - " + s)

if __name__ == "__main__":
    check_files()
