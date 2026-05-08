/**
 * Ejecutar una sola vez en Developer Console > Execute Anonymous:
 *   FormTemplateSeeder.seed();
 *
 * Migra las plantillas hardcodeadas de techServiceReview a Form_Template__c.
 * Tipos sin preguntas quedan como formulario libre (Preguntas__c = '[]').
 */
public class FormTemplateSeeder {

    public static void seed() {
        List<Form_Template__c> templates = buildTemplates();
        // Upsert por Tipo_Reporte__c (campo External ID)
        upsert templates Tipo_Reporte__c;
        System.debug('Plantillas sembradas: ' + templates.size());
    }

    private static List<Form_Template__c> buildTemplates() {
        List<Form_Template__c> result = new List<Form_Template__c>();
        Integer ord = 1;

        result.add(make('Bioenzmático',              ord++, 'utility:bucket',            bioenzimatico()));
        result.add(make('Limpieza de Trampa',         ord++, 'utility:filter',            limpiezaTrampa()));
        result.add(make('Recolección de Grasa',       ord++, 'utility:threedots_vertical',recoleccionGrasa()));
        result.add(make('Íntima',                     ord++, 'utility:cases',             intima()));
        result.add(make('Desazolve',                  ord++, 'utility:loop',              desazolve()));
        result.add(make('Ductos',                     ord++, 'utility:upload',            ductos()));
        result.add(make('Aplicación de retardante',   ord++, 'utility:shield',            retardante()));
        result.add(make('PLOM',                       ord++, 'utility:form',              '[]'));
        result.add(make('Aromatizante',               ord++, 'utility:form',              '[]'));
        result.add(make('Bacter',                     ord++, 'utility:form',              '[]'));
        result.add(make('Filtros',                    ord++, 'utility:form',              '[]'));
        result.add(make('Limpieza',                   ord++, 'utility:form',              '[]'));
        result.add(make('Control de Plaga',           ord++, 'utility:form',              '[]'));
        result.add(make('Instalación',                ord++, 'utility:form',              '[]'));
        result.add(make('Elcla',                      ord++, 'utility:form',              '[]'));
        result.add(make('Entrega',                    ord++, 'utility:form',              '[]'));

        return result;
    }

    private static Form_Template__c make(String tipo, Integer orden, String icono, String preguntas) {
        Form_Template__c t = new Form_Template__c();
        t.Name             = tipo;
        t.Tipo_Reporte__c  = tipo;
        t.Orden__c         = orden;
        t.Icono__c         = icono;
        t.Activo__c        = true;
        t.Preguntas__c     = preguntas;
        return t;
    }

    // ─── Plantillas ────────────────────────────────────────────────────────────

    private static String bioenzimatico() {
        List<Map<String,Object>> qs = new List<Map<String,Object>>();
        qs.add(radioQ('q1',  'Consumo total',              new List<String>{'Sí','No'}, null, null));
        qs.add(radioQ('q2',  'Motivo',                     new List<String>{'Función correcta','Desconexión / Otro'}, 'Desconexión / Otro', 'Se solicita al Jefe de mantenimiento, Chef y/o Gerente de Cocina refuercen con el personal de cocina evite jalar o dañar las mangueras que dosifican el producto.'));
        qs.add(radioQ('q3',  'Envase',                     new List<String>{'Buen estado','Maltratado'}, 'Maltratado', 'Se solicita al Jefe de mantenimiento, Chef y/o Gerente de Cocina refuercen con el personal de lavado que no coloque objetos sobre el bidón o equipo.'));
        qs.add(radioQ('q4',  'Sello seguridad',            new List<String>{'Sin alterar','Alterado'}, 'Alterado', 'Se solicita al Jefe de mantenimiento, Chef y/o Gerente de Cocina refuercen con el personal de lavado que no desconecten el producto o lo utilicen para otros fines.'));
        qs.add(radioQ('q5',  'Fugas tubería',              new List<String>{'Sí','No'}, null, null));
        qs.add(radioQ('q6',  'ED Programación',            new List<String>{'Correcto','Reprograma'}, null, null));
        qs.add(radioQ('q7',  'ED Estado físico',           new List<String>{'Buen estado','Maltratado'}, 'Maltratado', 'Se solicita reubicar el equipo dosificador para evitar accidentes. El equipo se encuentra en comodato y en caso de daños imputables al cliente deberá pagar el costo del mismo.'));
        qs.add(radioQ('q9',  'ED Conexión',                new List<String>{'Correcto','Desconectado'}, 'Desconectado', 'Se solicita al personal y responsable de cocina no desconectar el equipo dosificador del contacto asignado.'));
        qs.add(radioQ('q10', 'ED Ubicación',               new List<String>{'En su lugar','No se encuentra'}, 'No se encuentra', 'El equipo no se encontraba en su lugar al momento del servicio. Se solicita al responsable de cocina y/o jefe de mantenimiento notificar a PYATZ en caso de remodelación.'));
        qs.add(radioQ('q11', 'ED Desenergizado',           new List<String>{'Sí','NA'}, 'NA', 'Se solicita al Jefe de mantenimiento la revisión del contacto o indicar si existen horarios de desconexión para prevenir la desenergización del equipo.'));
        qs.add(radioQ('q12', 'Cambio de pila',             new List<String>{'Sí','No'}, null, null));
        qs.add(radioQ('q13', 'Fauna nociva',               new List<String>{'Sí','No'}, 'Sí', 'Se sugiere la fumigación de la zona e implementar políticas de separación de residuos sólidos y líquidos con disposición correcta para evitar la presencia de plagas.'));
        qs.add(radioQ('q14', 'Residuo tarjas',             new List<String>{'Sí','No'}, 'Sí', 'Se sugiere la disposición de sólidos orgánicos e inorgánicos en los botes de basura (mejorar el escamoche), evitando residuos en tarjas o coladeras.'));
        qs.add(radioQ('q15', 'Aceites o grasas en tarjas', new List<String>{'Sí','No'}, 'Sí', 'Se sugiere la separación del aceite en contenedor destinado para su correcta disposición.'));
        return JSON.serialize(qs);
    }

    private static String limpiezaTrampa() {
        List<Map<String,Object>> qs = new List<Map<String,Object>>();
        qs.add(radioQ('q1',  'Retiro sólidos',           new List<String>{'Alto','Medio','Bajo','Nulo'}, 'Nulo', 'Se exhorta a realizar una correcta disposición de sólidos orgánicos e inorgánicos en los botes de basura, evitando arrojar residuos en tarjas o coladeras.'));
        qs.add(radioQ('q2',  'Retiro harinas',           new List<String>{'Alto','Medio','Bajo','Nulo'}, 'Nulo', 'Se sugiere evitar el arrojo de harina en tarjas y la previa limpieza en seco (con papel) de utensilios con exceso de grasas y harinas.'));
        qs.add(radioQ('q3',  'Grasa líquida',            new List<String>{'Sí','No'}, 'Sí', 'Se sugiere la disposición de grasas y aceites en contenedores de plástico para su correcta disposición y así prevenir desbordamientos o azolves en trampa y tuberías.'));
        qs.add(numberQ('q4', 'Litros'));
        qs.add(numberQ('q5', 'Kilos'));
        qs.add(radioQ('q6',  'Estado de trampa',         new List<String>{'Bien','Regular','Mal'}, 'Mal', 'Se sugiere el cambio de la trampa de grasa dadas las deficiencias que presenta la actual.'));
        qs.add(radioQ('q7',  'Cierre de trampa',         new List<String>{'Perfecto','Bien','Regular','Mal','Muy mal'}, null, null));
        qs.add(radioQ('q8',  'Tornillos completos',      new List<String>{'Sí','No'}, 'No', 'Se sugiere la colocación de tornillos para prevenir desbordamientos de la trampa o tropiezos del personal.'));
        qs.add(radioQ('q9',  'Tornillos en buen estado', new List<String>{'Sí','No'}, 'No', 'Se sugiere cambio de tornillos y limpieza de la cuerda y cabeza de tornillo para conservar en mejor estado la función de estos y la tapa.'));
        qs.add(radioQ('q10', 'Sello en buen estado',     new List<String>{'Sí','No'}, 'No', 'Se exhorta al jefe de mantenimiento a realizar el cambio de sellos de la trampa de grasa para evitar desbordamientos o presencia de malos olores.'));
        qs.add(radioQ('q11', 'Tapa en buen estado',      new List<String>{'Sí','No'}, 'No', 'Se exhorta al jefe de mantenimiento a realizar el cambio de tapa de la trampa de grasa para evitar desbordamientos o presencia de malos olores.'));
        qs.add(radioQ('q12', 'Mamparas en buen estado',  new List<String>{'Sí','No'}, 'No', 'Se exhorta al jefe de mantenimiento a realizar el cambio de mamparas para asegurar el correcto funcionamiento de la trampa.'));
        qs.add(radioQ('q13', 'Fauna nociva',             new List<String>{'Sí','No'}, 'Sí', 'Se sugiere la fumigación de la zona e implementar políticas de separación de residuos sólidos y líquidos con disposición correcta para evitar la presencia de plagas.'));
        qs.add(radioQ('q14', 'Entorno en buen estado',   new List<String>{'Sí','No'}, 'No', 'Se sugiere el cambio de losetas para prevenir accidentes y mantener estándares de higiene en cocina.'));
        qs.add(radioQ('q15', 'Mobiliario sobre trampa',  new List<String>{'Sí','No'}, 'Sí', 'Se solicita al Jefe de mantenimiento, Chef y/o Gerente de Cocina eviten recargar muebles sobre tapas de trampas.'));
        return JSON.serialize(qs);
    }

    private static String recoleccionGrasa() {
        List<Map<String,Object>> qs = new List<Map<String,Object>>();
        qs.add(numberQ('q1', '# Bidones'));
        qs.add(numberQ('q2', '# Kilos totales'));
        return JSON.serialize(qs);
    }

    private static String intima() {
        List<Map<String,Object>> qs = new List<Map<String,Object>>();
        qs.add(radioQ('q1', 'Estado UHF',                                new List<String>{'Correcta','Desaparecida','Inaccesible','Reubicada','Rota','Pagada'}, null, null));
        qs.add(radioQ('q2', 'Maltratada',                                new List<String>{'Sí','No'}, 'Sí', 'Se exhorta al Jefe de mantenimiento y RH nos permitan realizar capacitaciones de refuerzo con el personal femenino para transmitir los beneficios del programa de Confinamiento temporal.'));
        qs.add(radioQ('q3', 'Rota',                                      new List<String>{'Sí','No'}, 'Sí', 'Se solicita que nos permitan realizar capacitaciones de refuerzo. La UHF se encuentra en comodato y en caso de daños imputables al cliente deberá pagar el costo del mismo.'));
        qs.add(radioQ('q4', 'UHF con residuos de sangre o basura',      new List<String>{'Sí','No'}, 'Sí', 'Se exhorta al Jefe de mantenimiento y RH nos permitan realizar capacitaciones de refuerzo con el personal femenino para transmitir los beneficios del programa.'));
        qs.add(radioQ('q5', 'UHF manipulada por personal ajeno a PYATZ', new List<String>{'Sí','No'}, 'Sí', 'Se exhorta al personal del cliente que no se realice manipulación del contenido hasta que nuestro personal se presente.'));
        qs.add(numberQ('q6', 'Kls RHF/Zona'));
        return JSON.serialize(qs);
    }

    private static String desazolve() {
        List<Map<String,Object>> qs = new List<Map<String,Object>>();
        qs.add(radioQ('q1',  'Exceso de sólidos en tarjas o tuberías',        new List<String>{'Sí','No'}, 'Sí', 'Se exhorta a realizar una correcta disposición de sólidos en los botes de basura, evitando arrojar residuos directamente o resultado de la acción de barren tarjas o coladeras.'));
        qs.add(radioQ('q2',  'Exceso de sólidos en coladeras o tuberías',     new List<String>{'Sí','No'}, 'Sí', 'Se exhorta a realizar una correcta disposición de sólidos en los botes de basura, evitando arrojar residuos directamente o resultado de la acción de barren tarjas o coladeras.'));
        qs.add(radioQ('q3',  'Conexiones entre tuberías deterioradas',         new List<String>{'Sí','No'}, 'Sí', 'El estado actual de las instalaciones representa un riesgo ya que al momento de realizar el desazolve mecánico se podrían abrir las conexiones de la tubería.'));
        qs.add(radioQ('q4',  'Desechos de sólidos en tubería',                new List<String>{'Sí','No'}, 'Sí', 'Solicitar al ingeniero reforzar prácticas con colaboradores y clientes para prevenir el taponamiento de las tuberías.'));
        qs.add(radioQ('q5',  'Bombas de vaciado sin energía',                 new List<String>{'Sí','No'}, 'Sí', 'Las bombas no se pueden accionar. Se exhorta al personal de mantenimiento realice un diagnóstico de su instalación y tablero eléctrico.'));
        qs.add(radioQ('q6',  'Bombas de vaciado con funcionamiento deficiente',new List<String>{'Sí','No'}, 'Sí', 'Las bombas se encuentran energizadas pero no es posible accionarlas. Se solicita al personal de mantenimiento realice la reparación de las bombas.'));
        qs.add(radioQ('q7',  'Tapa de cárcamo o registro atascada',           new List<String>{'Sí','No'}, 'Sí', 'Se requiere liberar la tapa para realizar el servicio. Se solicita a responsables de mantenimiento realizar la apertura y liberación del área.'));
        qs.add(radioQ('q8',  'Sin registros para acceder a sección afectada',  new List<String>{'Sí','No'}, 'Sí', 'Se requiere la apertura de registros adicionales en las instalaciones para poder realizar el servicio de desazolve ya que el área afectada es inaccesible.'));
        qs.add(radioQ('q9',  'No se realizó servicio por falta de acceso',    new List<String>{'Sí','No'}, 'Sí', 'El servicio no se realizó ya que no se contaba con el permiso de acceso o llaves. Se solicita al cliente tramite permisos de acceso previos al servicio.'));
        qs.add(textQ ('q10', 'Descripción inicial'));
        qs.add(textQ ('q11', 'Resultados'));
        return JSON.serialize(qs);
    }

    private static String ductos() {
        List<Map<String,Object>> qs = new List<Map<String,Object>>();
        qs.add(radioQ('q1', 'Instalaciones con ruptura antes de iniciar el trabajo', new List<String>{'Sí','No'}, 'Sí', 'Es necesario realizar el sellado de las fisuras y fugas que se presentan en el ducto de extracción para poder proceder con la ejecución del servicio.'));
        qs.add(radioQ('q2', 'Soportería dañada o deficiente',                        new List<String>{'Sí','No'}, 'Sí', 'Reforzar o sustituir soportería del ducto ya que el estado actual de la misma representa un riesgo de colapso para la instalación.'));
        qs.add(radioQ('q3', 'Falta de registros para acceso a ductos',               new List<String>{'Sí','No'}, 'Sí', 'Realizar registros necesarios para acceder a las áreas necesarias.'));
        qs.add(radioQ('q4', 'Detección de daño estructural de sección de ducto',     new List<String>{'Sí','No'}, 'Sí', 'Es necesario realizar la sustitución y colocación de una nueva sección de ducto de extracción ya que el daño en la sección afectada no puede ser reparada.'));
        qs.add(radioQ('q5', 'Ausencia de cortafuegos en trayectoria del ducto',      new List<String>{'Sí','No'}, 'Sí', 'Es necesaria y prioritaria la instalación de cortafuegos ya que es una medida de seguridad importante contra incendios en el ducto de extracción.'));
        qs.add(radioQ('q6', 'Cortafuego bloqueado (cerrado)',                         new List<String>{'Sí','No'}, 'Sí', 'El cortafuego se encuentra cerrado y bloqueado. Se requiere realizar la apertura del cortafuegos para dar libre paso a la extracción de los gases de cocina.'));
        qs.add(radioQ('q7', 'Objetos extraños atorados en cortafuegos',              new List<String>{'Sí','No'}, 'Sí', 'Se solicita al Jefe de mantenimiento, Chef y/o Gerente de Cocina refuercen con el personal de limpieza de campanas notificar si algún objeto fue succionado.'));
        qs.add(radioQ('q8', 'El trabajo se concluyó sin complicaciones',              new List<String>{'Sí','No'}, null, null));
        return JSON.serialize(qs);
    }

    private static String retardante() {
        List<Map<String,Object>> qs = new List<Map<String,Object>>();
        qs.add(radioQ('q1', 'Área libre',                         new List<String>{'Sí','No'}, 'No', 'Se solicita al cliente previo a los trabajos liberen la zona de aplicación de muebles u objetos ajenos a los trabajos que se realizarán para garantizar una aplicación uniforme y efectiva.'));
        qs.add(radioQ('q2', 'Presencia de aparatos electrónicos', new List<String>{'Sí','No'}, 'Sí', 'Se solicita al cliente previo a los trabajos desconecte y retire equipos electrónicos ubicados dentro de la zona de aplicación.'));
        return JSON.serialize(qs);
    }

    // ─── Constructores de preguntas ────────────────────────────────────────────

    private static Map<String,Object> radioQ(String id, String label,
                                              List<String> opts, String defOn, String def) {
        Map<String,Object> q = new Map<String,Object>{
            'id'    => id,
            'label' => label,
            'type'  => 'radio',
            'options' => opts
        };
        if (defOn != null) { q.put('defOn', defOn); q.put('def', def); }
        return q;
    }

    private static Map<String,Object> numberQ(String id, String label) {
        return new Map<String,Object>{ 'id' => id, 'label' => label, 'type' => 'number' };
    }

    private static Map<String,Object> textQ(String id, String label) {
        return new Map<String,Object>{ 'id' => id, 'label' => label, 'type' => 'text' };
    }
}