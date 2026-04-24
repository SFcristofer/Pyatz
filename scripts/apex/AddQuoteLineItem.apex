// Agrega un nuevo QuoteLineItem al Quote 0Q0V9000001uIbBKAU
// Ejecuta en Developer Console > Debug > Open Execute Anonymous Window

Id quoteId = '0Q0V9000001uIbBKAU';

// Obtener el Pricebook del Quote existente
Quote qt = [SELECT Id, Pricebook2Id FROM Quote WHERE Id = :quoteId LIMIT 1];
System.debug('Pricebook2Id: ' + qt.Pricebook2Id);

// Crear producto nuevo
Product2 prod = new Product2(
    Name        = 'ECOLAB OASIS PRO 146 - GARRAFA 20L',
    IsActive    = true,
    ProductCode = 'ECO-001',
    Description = 'Detergente concentrado para lavado de vajilla a mano'
);
insert prod;

// Primero crear entrada en el Pricebook Estándar (requerido siempre)
Id stdPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
PricebookEntry pbeStd = new PricebookEntry(
    Pricebook2Id = stdPbId,
    Product2Id   = prod.Id,
    UnitPrice    = 1250.00,
    IsActive     = true
);
insert pbeStd;

// Luego crear entrada en el pricebook del quote (si es distinto al estándar)
PricebookEntry pbe;
if (qt.Pricebook2Id != stdPbId) {
    pbe = new PricebookEntry(
        Pricebook2Id = qt.Pricebook2Id,
        Product2Id   = prod.Id,
        UnitPrice    = 1250.00,
        IsActive     = true
    );
    insert pbe;
} else {
    pbe = pbeStd;
}

// Descripción detallada con mucho texto (similar a los existentes)
String detalle = '<p><strong>Descripción del producto:</strong></p>'
    + '<p>Detergente líquido concentrado de alta eficiencia formulado para el lavado manual de vajilla, '
    + 'utensilios de cocina y superficies en contacto con alimentos. Su fórmula biodegradable remueve '
    + 'eficazmente grasa, residuos de alimentos y manchas difíciles sin dañar las manos ni los materiales.</p>'
    + '<p><strong>Especificaciones técnicas:</strong></p>'
    + '<ul>'
    + '<li>Presentación: Garrafa de 20 litros</li>'
    + '<li>Dilución recomendada: 1:200 a 1:500 (según nivel de suciedad)</li>'
    + '<li>pH: 7.0 - 8.5 (neutro a ligeramente alcalino)</li>'
    + '<li>Espumado: Alto, facilita el arrastre mecánico de suciedad</li>'
    + '<li>Certificación: NSF A1 para uso en industria alimentaria</li>'
    + '<li>Biodegradabilidad: &gt;90% en 28 días (OCDE 301B)</li>'
    + '</ul>'
    + '<p><strong>Instrucciones de uso:</strong></p>'
    + '<ul>'
    + '<li>Diluir según concentración requerida en agua tibia</li>'
    + '<li>Aplicar con esponja o fibra sobre superficies a limpiar</li>'
    + '<li>Enjuagar con abundante agua limpia</li>'
    + '<li>No mezclar con productos clorados o ácidos</li>'
    + '<li>Usar guantes de protección durante la aplicación</li>'
    + '</ul>'
    + '<p><strong>Rendimiento estimado:</strong> 1 garrafa = aprox. 4,000 litros de solución a dilución 1:200. '
    + 'Ideal para cocinas industriales con alto volumen de operación.</p>';

QuoteLineItem qli = new QuoteLineItem(
    QuoteId                  = quoteId,
    Product2Id               = prod.Id,
    PricebookEntryId         = pbe.Id,
    Quantity                 = 3,
    UnitPrice                = 1250.00,
    Description              = 'Detergente concentrado',
    Descripcion_Detallada__c = detalle
);
insert qli;

System.debug('=== LINE ITEM CREADO ===');
System.debug('QuoteLineItem ID: ' + qli.Id);
System.debug('URL PDF: /apex/QuoteTechnicalPDF?id=' + quoteId);
