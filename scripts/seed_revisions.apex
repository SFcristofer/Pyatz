// Seed: fill all revisions of WO 0WOV90000071oDSOAY with realistic fake data
// Run: sf apex run --target-org PYATZ --file scripts/seed_revisions.apex

String TECNICO_ID = '005V900000G1PjZIAV'; // GUILLERMO AGUIRRE HERNANDEZ

Map<String, String> PLANTILLA_MAP = new Map<String, String>{
    'Bioenzmático'         => 'a16V9000000xVm9IAE',
    'Bioenzimático'        => 'a16V9000000xVm9IAE',
    'Bioenzematico'        => 'a16V9000000xcajIAA',
    'Íntima'               => 'a16V9000000xVmCIAU',
    'Bacter'               => 'a16V9000000xVmIIAU',
    'Desazolve'            => 'a16V9000000xVmDIAU',
    'Recolección de Grasa' => 'a16V9000000xVmBIAU'
};

List<String> NOMBRES = new List<String>{
    'Carlos Mendoza García',
    'Ana Laura Pérez Torres',
    'Roberto Jiménez Salinas',
    'María Elena Gutiérrez Vega',
    'Fernando Castillo Reyes',
    'Lucía Ramírez Cruz'
};
List<String> CARGOS = new List<String>{
    'Gerente de Operaciones',
    'Jefe de Mantenimiento',
    'Chef Ejecutivo',
    'Gerente General',
    'Supervisor de Producción',
    'Coordinador de Servicios'
};

// JSON templates por tipo (2 variantes por tipo para variedad)
Map<String, String> JSONS = new Map<String, String>{
    'BIOENZ_A'    => '{"q1":"Sí","q2":"Función correcta","q3":"Buen estado","q4":"Sin alterar","q5":"No","q6":"Correcto","q7":"Buen estado","q9":"Conectado","q10":"En su lugar","q11":"NA","q12":"No","q13":"No","q14":"No","q15":"No"}',
    'BIOENZ_B'    => '{"q1":"Sí","q2":"Función correcta","q3":"Buen estado","q4":"Sin alterar","q5":"No","q6":"Correcto","q7":"Buen estado","q9":"Conectado","q10":"En su lugar","q11":"Energizado","q12":"No","q13":"Sí","q14":"No","q15":"Sí"}',
    'GRASA_A'     => '{"q1":"2","q2":"38.5"}',
    'GRASA_B'     => '{"q1":"3","q2":"52.0"}',
    'GRASA_C'     => '{"q1":"1","q2":"24.0"}',
    'INTIMA_A'    => '{"q1":"Correcta","q2":"No","q3":"No","q4":"No","q5":"No","q6":"11.5"}',
    'INTIMA_B'    => '{"q1":"Correcta","q2":"No","q3":"No","q4":"Sí","q5":"No","q6":"8.0"}',
    'BACTER_A'    => '{"obs":"Se aplicó solución bactericida en área de cocina. Superficies sanitizadas correctamente. Sin evidencia de contaminación activa."}',
    'BACTER_B'    => '{"obs":"Aplicación de bactericida en zona de almacén y área de carga. Producto diluido al 2%. Tiempo de contacto: 15 minutos."}',
    'DESAZOLVE_A' => '{"obs":"Se realizó desazolve de trampa de grasa. Extracción de lodos y residuos acumulados. Trampa en condición operativa al finalizar."}',
    'DESAZOLVE_B' => '{"obs":"Desazolve preventivo. Trampa con nivel de llenado al 40%. Se eliminaron residuos sólidos y se verificó flujo libre."}',
    'RESIDUAL_A'  => '{"obs":"Aplicación de insecticida residual en rodapiés y áreas de tránsito. Sin presencia de fauna nociva activa."}',
    'RESIDUAL_B'  => '{"obs":"Tratamiento residual en perímetro de cocina y área de servicio. Puntos de infestación previos sin actividad."}',
    'DEFAULT'     => '{"obs":"Servicio realizado conforme a protocolo establecido. Sin anomalías reportadas."}'
};

List<Revision_Cita_Servicio__c> revs = [
    SELECT Id, Tipo_Reporte__c, Status__c, Nombre_Firmante__c, Cargo_Firmante__c,
           Fecha_Revision__c, Observaciones__c, Tecnico__c, Datos_Formulario__c,
           Plantilla_de_Formulario__c, Numero_Revision__c
    FROM Revision_Cita_Servicio__c
    WHERE Cita_Servicio__r.ParentRecordId = '0WOV90000071oDSOAY'
    ORDER BY Numero_Revision__c ASC NULLS LAST
];
System.debug('Total revisiones encontradas: ' + revs.size());

List<Revision_Cita_Servicio__c> toUpdate = new List<Revision_Cita_Servicio__c>();
Date baseDate = Date.newInstance(2026, 4, 15);
Integer idx   = 0;

for (Revision_Cita_Servicio__c rev : revs) {
    String tipo = rev.Tipo_Reporte__c != null ? rev.Tipo_Reporte__c.trim() : '';
    String tipoLower = tipo.toLowerCase();
    Integer v = Math.mod(idx, 2); // variante 0 o 1

    String jsonData;
    String obs;
    String plantillaId = PLANTILLA_MAP.get(tipo);

    if (tipo == 'Bioenzmático' || tipo == 'Bioenzimático' || tipo == 'Bioenzematico') {
        jsonData = v == 0 ? JSONS.get('BIOENZ_A') : JSONS.get('BIOENZ_B');
        obs = 'Servicio de dosificación bioenzimática ejecutado. Equipo revisado y calibrado correctamente.';
    } else if (tipo == 'Recolección de Grasa') {
        if      (Math.mod(idx, 3) == 0) jsonData = JSONS.get('GRASA_A');
        else if (Math.mod(idx, 3) == 1) jsonData = JSONS.get('GRASA_B');
        else                            jsonData = JSONS.get('GRASA_C');
        obs = 'Recolección de bidones de grasa completada. Área limpia al finalizar servicio.';
    } else if (tipo == 'Íntima') {
        jsonData = v == 0 ? JSONS.get('INTIMA_A') : JSONS.get('INTIMA_B');
        obs = 'Inspección de unidades de higiene. Estado general bueno, sin daños ni manipulación.';
    } else if (tipo == 'Bacter') {
        jsonData = v == 0 ? JSONS.get('BACTER_A') : JSONS.get('BACTER_B');
        obs = 'Aplicación bactericida completada. Sin observaciones adicionales.';
    } else if (tipo == 'Desazolve') {
        jsonData = v == 0 ? JSONS.get('DESAZOLVE_A') : JSONS.get('DESAZOLVE_B');
        obs = 'Desazolve de trampa completado. Sin anomalías en el sistema de drenaje.';
    } else if (tipoLower.contains('residual')) {
        jsonData = v == 0 ? JSONS.get('RESIDUAL_A') : JSONS.get('RESIDUAL_B');
        obs = 'Tratamiento residual aplicado en zona asignada. Área verificada post-aplicación.';
    } else {
        jsonData = JSONS.get('DEFAULT');
        obs = 'Servicio ejecutado conforme a protocolo. Sin anomalías.';
    }

    // Fechas distribuidas entre 15 Abr – 20 May 2026 (35 días, paso de 3)
    Integer dayOff = Math.mod(idx * 3, 35);
    Integer hour   = 8 + Math.mod(idx, 5) * 2; // 8, 10, 12, 14, 16 hrs
    DateTime fechaRev = DateTime.newInstance(
        baseDate.addDays(dayOff),
        Time.newInstance(hour, 0, 0, 0)
    );

    rev.Status__c               = 'Completada';
    rev.Tecnico__c              = TECNICO_ID;
    rev.Datos_Formulario__c     = jsonData;
    rev.Fecha_Revision__c       = fechaRev;
    rev.Observaciones__c        = obs;
    rev.Nombre_Firmante__c      = NOMBRES.get(Math.mod(idx, NOMBRES.size()));
    rev.Cargo_Firmante__c       = CARGOS.get(Math.mod(idx, CARGOS.size()));
    // Plantilla no se toca: validación impide cambiarla si ya hay datos en el formulario

    toUpdate.add(rev);
    idx++;
}

update toUpdate;
System.debug('SUCCESS: ' + toUpdate.size() + ' revisiones actualizadas.');
