const fs = require('fs');
const path = require('path');

function getLocalMetadata(forceAppDir) {
    const localMeta = {};
    const folderToType = {
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
        'flow': 'Flow',
        'flows': 'Flow',
        'globalValueSets': 'GlobalValueSet',
        'standardValueSets': 'StandardValueSet',
        'labels': 'CustomLabels',
        'staticresources': 'StaticResource'
    };

    function traverse(dir) {
        if (!fs.existsSync(dir)) return;
        const files = fs.readdirSync(dir);
        for (const file of files) {
            const fullPath = path.join(dir, file);
            const stat = fs.statSync(fullPath);
            if (stat.isDirectory()) {
                const parts = path.relative(forceAppDir, fullPath).split(path.sep);
                const baseFolder = parts[0];
                const metaType = folderToType[baseFolder];
                
                if (metaType === 'CustomObject') {
                    if (parts.length === 2) {
                        localMeta['CustomObject'] = localMeta['CustomObject'] || new Set();
                        localMeta['CustomObject'].add(parts[1]);
                    } else if (parts.length === 3 && parts[2] === 'fields') {
                        traverse(fullPath);
                    }
                } else if (metaType === 'LightningComponentBundle' || metaType === 'AuraDefinitionBundle') {
                    if (parts.length === 2) {
                        localMeta[metaType] = localMeta[metaType] || new Set();
                        localMeta[metaType].add(parts[1]);
                    }
                } else {
                    traverse(fullPath);
                }
            } else {
                const parts = path.relative(forceAppDir, fullPath).split(path.sep);
                const baseFolder = parts[0];
                const metaType = folderToType[baseFolder];
                
                if (metaType === 'CustomObject' && parts.length === 4 && parts[2] === 'fields') {
                    if (file.endsWith('.field-meta.xml')) {
                        const objName = parts[1];
                        const fieldName = file.replace('.field-meta.xml', '');
                        localMeta['CustomField'] = localMeta['CustomField'] || new Set();
                        localMeta['CustomField'].add(`${objName}.${fieldName}`);
                    }
                } else if (metaType && metaType !== 'LightningComponentBundle' && metaType !== 'AuraDefinitionBundle' && metaType !== 'CustomObject') {
                    if (file.endsWith('-meta.xml') || file.endsWith('.xml')) {
                        let name = file.split('.')[0];
                        if (name) {
                            localMeta[metaType] = localMeta[metaType] || new Set();
                            localMeta[metaType].add(name);
                        }
                    } else if (file.endsWith('.cls') && metaType === 'ApexClass') {
                        localMeta[metaType] = localMeta[metaType] || new Set();
                        localMeta[metaType].add(file.replace('.cls', ''));
                    }
                }
            }
        }
    }
    traverse(forceAppDir);
    return localMeta;
}

function getOrgMetadata(manifestPath) {
    const orgMeta = {};
    if (!fs.existsSync(manifestPath)) return orgMeta;
    
    const content = fs.readFileSync(manifestPath, 'utf8');
    const typesRegex = /<types>([\s\S]*?)<\/types>/g;
    let match;
    
    while ((match = typesRegex.exec(content)) !== null) {
        const typeBlock = match[1];
        const nameMatch = /<name>(.*?)<\/name>/.exec(typeBlock);
        if (nameMatch) {
            const metaType = nameMatch[1];
            orgMeta[metaType] = new Set();
            
            const memberRegex = /<members>(.*?)<\/members>/g;
            let memberMatch;
            while ((memberMatch = memberRegex.exec(typeBlock)) !== null) {
                orgMeta[metaType].add(memberMatch[1]);
            }
        }
    }
    return orgMeta;
}

function main() {
    const localDir = 'C:/Users/crist/OneDrive/Documentos/Proyecto pyatz/Pyatz/force-app/main/default';
    const manifestPath = 'C:/Users/crist/OneDrive/Documentos/Proyecto pyatz/Pyatz/manifest/org_manifest.xml';
    
    const local = getLocalMetadata(localDir);
    const org = getOrgMetadata(manifestPath);
    
    console.log("=== DISCREPANCY ANALYSIS ===");
    
    const typesToCheck = ['ApexClass', 'LightningComponentBundle', 'CustomObject', 'CustomField', 'ApexTrigger', 'FlexiPage', 'Flow'];
    
    for (const t of typesToCheck) {
        console.log(`\n--- ${t} ---`);
        const orgSet = org[t] || new Set();
        const localSet = local[t] || new Set();
        
        const inOrgNotLocal = new Set([...orgSet].filter(x => !localSet.has(x)));
        // Ignore managed packages with namespaces (usually containing __ in the prefix, but not __c)
        const inOrgNotLocalFiltered = [...inOrgNotLocal].filter(x => !(x.includes('__') && !x.endsWith('__c') && !x.endsWith('__mdt')));
        
        if (inOrgNotLocalFiltered.length > 0) {
            console.log(`[${inOrgNotLocalFiltered.length}] In Org ONLY (missing locally):`);
            inOrgNotLocalFiltered.sort().slice(0, 30).forEach(item => console.log(`  + ${item}`));
            if (inOrgNotLocalFiltered.length > 30) {
                console.log(`  ... and ${inOrgNotLocalFiltered.length - 30} more`);
            }
        }
        
        const inLocalNotOrg = [...localSet].filter(x => !orgSet.has(x));
        if (inLocalNotOrg.length > 0) {
            console.log(`[${inLocalNotOrg.length}] In Local ONLY (not deployed to org):`);
            inLocalNotOrg.sort().slice(0, 30).forEach(item => console.log(`  - ${item}`));
            if (inLocalNotOrg.length > 30) {
                console.log(`  ... and ${inLocalNotOrg.length - 30} more`);
            }
        }
        
        if (inOrgNotLocalFiltered.length === 0 && inLocalNotOrg.length === 0) {
            console.log("  ✓ Perfectly synced");
        }
    }
}

main();
