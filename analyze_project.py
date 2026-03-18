import os
import json
import re

def analyze_apex(classes_dir):
    apex_info = []
    if not os.path.exists(classes_dir):
        return apex_info
    
    for filename in os.listdir(classes_dir):
        if filename.endswith(".cls"):
            with open(os.path.join(classes_dir, filename), 'r', encoding='utf-8') as f:
                content = f.read()
                methods = re.findall(r'(?:public|private|global)\s+(?:static\s+)?(?:[\w<>,\[\]\s]+)\s+(\w+)\s*\(', content)
                aura_enabled = len(re.findall(r'@AuraEnabled', content))
                callouts = len(re.findall(r'Http\s+h\s*=\s*new\s+Http', content))
                queries = len(re.findall(r'\[SELECT', content, re.IGNORECASE))
                
                apex_info.append({
                    'class_name': filename.replace('.cls', ''),
                    'methods': list(set(methods)),
                    'aura_enabled_methods': aura_enabled,
                    'has_callouts': callouts > 0,
                    'soql_queries': queries
                })
    return apex_info

def analyze_lwc(lwc_dir):
    lwc_info = []
    if not os.path.exists(lwc_dir):
        return lwc_info
        
    for comp_name in os.listdir(lwc_dir):
        comp_path = os.path.join(lwc_dir, comp_name)
        if os.path.isdir(comp_path):
            js_file = os.path.join(comp_path, f"{comp_name}.js")
            html_file = os.path.join(comp_path, f"{comp_name}.html")
            
            imports = []
            apex_calls = []
            events = []
            
            if os.path.exists(js_file):
                with open(js_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    imports = re.findall(r'import\s+.*?\s+from\s+[\'"](.*?)[\'"]', content)
                    apex_calls = re.findall(r'@salesforce/apex/(\w+\.\w+)', content)
                    events = re.findall(r'new\s+CustomEvent\([\'"](.*?)[\'"]', content)
                    
            lwc_info.append({
                'component_name': comp_name,
                'imports': list(set(imports)),
                'apex_calls': list(set(apex_calls)),
                'custom_events_dispatched': list(set(events)),
                'has_html': os.path.exists(html_file)
            })
    return lwc_info

def analyze_objects(objects_dir):
    obj_info = []
    if not os.path.exists(objects_dir):
        return obj_info
        
    for obj_name in os.listdir(objects_dir):
        obj_path = os.path.join(objects_dir, obj_name)
        if os.path.isdir(obj_path):
            fields_dir = os.path.join(obj_path, 'fields')
            fields = []
            if os.path.exists(fields_dir):
                for field_file in os.listdir(fields_dir):
                    if field_file.endswith('.field-meta.xml'):
                        fields.append(field_file.replace('.field-meta.xml', ''))
            obj_info.append({
                'object_name': obj_name,
                'custom_fields': fields
            })
    return obj_info

def analyze_pages(pages_dir):
    page_info = []
    if not os.path.exists(pages_dir):
        return page_info
        
    for filename in os.listdir(pages_dir):
        if filename.endswith(".page"):
            with open(os.path.join(pages_dir, filename), 'r', encoding='utf-8') as f:
                content = f.read()
                controller = re.search(r'standardController="([^"]+)"', content)
                extensions = re.search(r'extensions="([^"]+)"', content)
                page_info.append({
                    'page_name': filename,
                    'controller': controller.group(1) if controller else None,
                    'extensions': extensions.group(1) if extensions else None
                })
    return page_info

def main():
    base_dir = "force-app/main/default"
    
    report = "# Reporte Exhaustivo del Proyecto Pyatz (Salesforce)\n\n"
    report += "## 1. Arquitectura de Clases Apex\n\n"
    
    apex_classes = analyze_apex(os.path.join(base_dir, "classes"))
    for cls in apex_classes:
        report += f"### {cls['class_name']}\n"
        report += f"- **Métodos (@AuraEnabled)**: {cls['aura_enabled_methods']}\n"
        report += f"- **Consultas SOQL**: {cls['soql_queries']}\n"
        report += f"- **Llamadas Externas (Callouts)**: {'Sí' if cls['has_callouts'] else 'No'}\n"
        report += f"- **Métodos Detectados**: {', '.join(cls['methods'][:10])}...\n\n"
        
    report += "## 2. Componentes Lightning Web Components (LWC)\n\n"
    lwcs = analyze_lwc(os.path.join(base_dir, "lwc"))
    for lwc in lwcs:
        report += f"### {lwc['component_name']}\n"
        if lwc['apex_calls']:
            report += f"- **Dependencias Apex**: {', '.join(lwc['apex_calls'])}\n"
        if lwc['imports']:
            report += f"- **Módulos Importados**: {', '.join(lwc['imports'])}\n"
        if lwc['custom_events_dispatched']:
            report += f"- **Eventos Disparados**: {', '.join(lwc['custom_events_dispatched'])}\n"
        report += "\n"
        
    report += "## 3. Modelo de Datos (Objetos)\n\n"
    objs = analyze_objects(os.path.join(base_dir, "objects"))
    for obj in objs:
        report += f"### {obj['object_name']}\n"
        if obj['custom_fields']:
            report += f"- **Campos Personalizados**: {', '.join(obj['custom_fields'])}\n"
        else:
            report += "- *(Sin campos personalizados detectados en la estructura standard de metadatos o no es un objeto custom)*\n"
        report += "\n"
        
    report += "## 4. Páginas Visualforce\n\n"
    pages = analyze_pages(os.path.join(base_dir, "pages"))
    for page in pages:
        report += f"### {page['page_name']}\n"
        report += f"- **Controlador Standard**: {page['controller']}\n"
        report += f"- **Extensiones**: {page['extensions']}\n\n"
        
    report += "## 5. Integraciones y Dependencias Externas\n\n"
    report += "Basado en el análisis de Apex:\n"
    slack_cls = next((c for c in apex_classes if c['class_name'] == 'SlackIntegrationController'), None)
    if slack_cls and slack_cls['has_callouts']:
        report += "- **Slack API**: Se detectó integración nativa con Slack a través de `SlackIntegrationController` haciendo HTTP Callouts.\n"
        
    with open("ANALYSIS_REPORT.md", "w", encoding='utf-8') as f:
        f.write(report)
        
    print("Reporte generado en ANALYSIS_REPORT.md")

if __name__ == "__main__":
    main()
