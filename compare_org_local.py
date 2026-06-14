import os
import xml.etree.ElementTree as ET
from collections import defaultdict
import glob

def get_local_metadata(force_app_dir):
    local_meta = defaultdict(set)
    
    # Simple mapping based on folder names
    # Mapping folder names to XML names (approximate for most common types)
    folder_to_type = {
        'classes': 'ApexClass',
        'pages': 'ApexPage',
        'components': 'ApexComponent',
        'triggers': 'ApexTrigger',
        'lwc': 'LightningComponentBundle',
        'aura': 'AuraDefinitionBundle',
        'objects': 'CustomObject',
        'layouts': 'Layout',
        'permissionsets': 'PermissionSet',
        'profiles': 'Profile',
        'tabs': 'CustomTab',
        'applications': 'CustomApplication',
        'flexipages': 'FlexiPage',
        'flow': 'Flow', # sometimes flows
        'flows': 'Flow',
        'globalValueSets': 'GlobalValueSet',
        'standardValueSets': 'StandardValueSet',
        'labels': 'CustomLabels', # special case
        'staticresources': 'StaticResource'
    }

    # Iterate through folders
    for root, dirs, files in os.walk(force_app_dir):
        # We only care about main folders under main/default
        rel_path = os.path.relpath(root, force_app_dir)
        parts = rel_path.split(os.sep)
        
        if len(parts) >= 1 and parts[0] in folder_to_type:
            meta_type = folder_to_type[parts[0]]
            
            # For objects, we also need to get fields
            if meta_type == 'CustomObject':
                if len(parts) == 1:
                    for d in dirs:
                        local_meta['CustomObject'].add(d)
                elif len(parts) == 3 and parts[2] == 'fields':
                    obj_name = parts[1]
                    for f in files:
                        if f.endswith('.field-meta.xml'):
                            local_meta['CustomField'].add(f"{obj_name}.{f.replace('.field-meta.xml', '')}")
            elif meta_type == 'LightningComponentBundle' or meta_type == 'AuraDefinitionBundle':
                if len(parts) == 1:
                    for d in dirs:
                        local_meta[meta_type].add(d)
            else:
                for f in files:
                    if f.endswith('-meta.xml') or f.endswith('.xml'):
                        # Exclude the -meta.xml part
                        name = f.split('.')[0]
                        if name:
                            local_meta[meta_type].add(name)
                            
    return local_meta

def get_org_metadata(manifest_path):
    org_meta = defaultdict(set)
    if not os.path.exists(manifest_path):
        print(f"Error: {manifest_path} not found")
        return org_meta
        
    tree = ET.parse(manifest_path)
    root = tree.getroot()
    # Namespace is usually xmlns="http://soap.sforce.com/2006/04/metadata"
    ns = {'ns': 'http://soap.sforce.com/2006/04/metadata'}
    
    for types in root.findall('ns:types', ns):
        name_node = types.find('ns:name', ns)
        if name_node is not None:
            meta_type = name_node.text
            for member in types.findall('ns:members', ns):
                org_meta[meta_type].add(member.text)
                
    return org_meta

def main():
    local_dir = 'C:/Users/crist/OneDrive/Documentos/Proyecto pyatz/Pyatz/force-app/main/default'
    manifest_path = 'C:/Users/crist/OneDrive/Documentos/Proyecto pyatz/Pyatz/manifest/org_manifest.xml'
    
    local = get_local_metadata(local_dir)
    org = get_org_metadata(manifest_path)
    
    print("=== DISCREPANCY ANALYSIS ===")
    
    types_to_check = ['ApexClass', 'LightningComponentBundle', 'CustomObject', 'CustomField', 'ApexTrigger', 'FlexiPage', 'Flow']
    
    for t in types_to_check:
        print(f"\\n--- {t} ---")
        org_set = org.get(t, set())
        local_set = local.get(t, set())
        
        # In Org but NOT Local
        in_org_not_local = org_set - local_set
        # Ignore managed packages with namespaces (usually containing __ in the prefix, but not __c)
        in_org_not_local = {x for x in in_org_not_local if not ('__' in x and not x.endswith('__c'))}
        
        if in_org_not_local:
            print(f"[{len(in_org_not_local)}] In Org ONLY (missing locally):")
            for item in sorted(list(in_org_not_local))[:20]:
                print(f"  + {item}")
            if len(in_org_not_local) > 20:
                print(f"  ... and {len(in_org_not_local) - 20} more")
                
        in_local_not_org = local_set - org_set
        if in_local_not_org:
            print(f"[{len(in_local_not_org)}] In Local ONLY (not deployed to org):")
            for item in sorted(list(in_local_not_org))[:20]:
                print(f"  - {item}")
            if len(in_local_not_org) > 20:
                print(f"  ... and {len(in_local_not_org) - 20} more")
                
        if not in_org_not_local and not in_local_not_org:
            print("  ✓ Perfectly synced")

if __name__ == '__main__':
    main()
