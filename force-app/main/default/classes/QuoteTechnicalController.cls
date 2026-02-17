public with sharing class QuoteTechnicalController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getQuoteStats() {
        Map<String, Integer> stats = new Map<String, Integer>{
            'Total' => 0,
            'Aprobada' => 0,
            'Pendiente' => 0,
            'Rechazada' => 0,
            'Actualizada' => 0
        };
        
        for (AggregateResult ar : [SELECT Status, COUNT(Id) total FROM Quote GROUP BY Status]) {
            String status = (String)ar.get('Status');
            Integer count = (Integer)ar.get('total');
            stats.put('Total', stats.get('Total') + count);
            
            if (status == 'Approved' || status == 'Aprobada') stats.put('Aprobada', count);
            else if (status == 'Draft' || status == 'Borrador' || status == 'Pendiente') stats.put('Pendiente', stats.get('Pendiente') + count);
            else if (status == 'Rejected' || status == 'Rechazada') stats.put('Rechazada', count);
            else if (status == 'Actualizada') stats.put('Actualizada', count);
        }
        return stats;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getQuotesList() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for(Quote q : [SELECT Id, QuoteNumber, Name, Account.Name, Status, GrandTotal, CreatedDate, CreatedBy.Name 
                       FROM Quote ORDER BY CreatedDate DESC LIMIT 50]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('id', q.Id);
            row.put('folio', q.QuoteNumber);
            row.put('asunto', q.Name);
            row.put('cliente', q.Account.Name);
            row.put('generadoPor', q.CreatedBy.Name);
            row.put('fecha', q.CreatedDate);
            row.put('monto', q.GrandTotal);
            row.put('estado', q.Status);
            String statusClass = 'slds-font-weight_bold ';
            if(q.Status == 'Approved' || q.Status == 'Aprobada') statusClass += 'slds-text-color_success';
            else if(q.Status == 'Draft' || q.Status == 'Borrador') statusClass += 'slds-text-color_weak';
            else if(q.Status == 'Rejected' || q.Status == 'Rechazada') statusClass += 'slds-text-color_error';
            else statusClass += 'slds-text-color_info';
            row.put('estadoClass', statusClass);
            row.put('sede', 'Sede Principal'); 
            result.add(row);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInitialData(Id recordId) {
        Map<String, Object> result = new Map<String, Object>();
        Id accountId;
        
        if(recordId != null) {
            String sObjectType = recordId.getSObjectType().getDescribe().getName();
            if(sObjectType == 'Quote') {
                Quote q = [SELECT Id, Name, QuoteNumber, AccountId, Status, Description, 
                           Selected_Plan_URL__c, Markers_Data__c, Introduction_Text__c, 
                           Warranty_Text__c, Business_Lines_Selected__c, Technical_Sedes__c,
                           Show_Introduction__c, Show_Warranty__c, ExpirationDate,
                           (SELECT Id, Product2.Name, PricebookEntryId, Quantity, UnitPrice, ListPrice, Discount, Description, TotalPrice 
                            FROM QuoteLineItems)
                           FROM Quote WHERE Id = :recordId];
                accountId = q.AccountId;
                result.put('quote', q);
            } else if(sObjectType == 'Opportunity') {
                Opportunity opp = [SELECT Id, Name, AccountId, Account.Name, Pricebook2Id FROM Opportunity WHERE Id = :recordId];
                accountId = opp.AccountId;
                result.put('opportunity', opp);
            }
        }

        // NECESIDADES (Si hay cuenta)
        if (accountId != null) {
            result.put('necesidades', [SELECT Id, Name, Linea_de_negocio__c FROM Necesidades__c WHERE Cuenta__c = :accountId LIMIT 20]);
        }
        
        // UBICACIONES
        List<Id> locationIds = new List<Id>();
        for(AssociatedLocation al : [SELECT LocationId FROM AssociatedLocation WHERE ParentRecordId = :accountId]) {
            locationIds.add(al.LocationId);
        }
        if(!locationIds.isEmpty()) {
            result.put('locations', [SELECT Id, Name, LocationType, Description, VisitorAddress.Address FROM Location WHERE Id IN :locationIds LIMIT 20]);
        } else {
            result.put('locations', [SELECT Id, Name, LocationType, Description, VisitorAddress.Address FROM Location WHERE IsInventoryLocation = false LIMIT 10]);
        }

        // CONTACTOS (MOSTRANDO TODOS POR AHORA)
        result.put('contacts', [SELECT Id, Name, Phone, Email, AccountId, Account.Name, MailingStreet, MailingCity, MailingState 
                                FROM Contact LIMIT 100]);
        
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBusinessLineOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult = Product2.Family.getDescribe();
        for(Schema.PicklistEntry f : fieldResult.getPicklistValues()) {
            if(f.isActive()) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', f.getLabel());
                option.put('value', f.getValue());
                options.add(option);
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchProducts(String searchTerm, Id quoteId, List<String> businessLines, Boolean allowOtherLines) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        Id pricebookId;
        
        if (quoteId != null) {
            String sObjectType = quoteId.getSObjectType().getDescribe().getName();
            if (sObjectType == 'Quote') {
                pricebookId = [SELECT Pricebook2Id FROM Quote WHERE Id = :quoteId].Pricebook2Id;
            } else if (sObjectType == 'Opportunity') {
                pricebookId = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :quoteId].Pricebook2Id;
            }
        }

        if (pricebookId == null) {
            try { pricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id; } catch(Exception e) {}
        }

        String query = '%' + searchTerm + '%';
        
        // Construcción dinámica de la consulta
        String soql = 'SELECT Id, Product2.Name, Product2.Description, UnitPrice ' +
                      'FROM PricebookEntry ' +
                      'WHERE Pricebook2Id = :pricebookId ' +
                      'AND (Product2.Name LIKE :query OR Product2.ProductCode LIKE :query) ' +
                      'AND IsActive = true ';

        // Filtro por Líneas de Negocio (Family)
        if (!allowOtherLines && businessLines != null && !businessLines.isEmpty()) {
            soql += 'AND Product2.Family IN :businessLines ';
        }

        soql += 'LIMIT 15';

        if(pricebookId != null) {
            for (PricebookEntry pbe : Database.query(soql)) {
                Map<String, Object> item = new Map<String, Object>();
                item.put('id', pbe.Id);
                item.put('name', pbe.Product2.Name);
                item.put('description', pbe.Product2.Description);
                item.put('unitPrice', pbe.UnitPrice);
                results.add(item);
            }
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchNecesidades(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        String query = '%' + searchTerm + '%';
        for (Necesidades__c n : [SELECT Id, Name, Linea_de_negocio__c FROM Necesidades__c 
                                WHERE Name LIKE :query OR Linea_de_negocio__c LIKE :query LIMIT 10]) {
            Map<String, String> res = new Map<String, String>();
            res.put('id', n.Id);
            res.put('name', n.Name + ' (' + n.Linea_de_negocio__c + ')');
            results.add(res);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEmailTemplatesByFolder(String folderName) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        // Buscamos plantillas que pertenezcan a carpetas que empiecen con 'Pyatz'
        for (EmailTemplate et : [SELECT Id, Name, Subject, Description 
                                FROM EmailTemplate 
                                WHERE Folder.Name = :folderName AND IsActive = true
                                ORDER BY Name ASC]) {
            Map<String, String> res = new Map<String, String>();
            res.put('id', et.Id);
            res.put('name', et.Name);
            res.put('description', et.Description);
            results.add(res);
        }
        return results;
    }

    @AuraEnabled
    public static String renderTemplate(Id templateId, Id quoteId) {
        try {
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, null, quoteId);
            String htmlBody = rendered.getHtmlBody();
            
            // Limpieza: Extraer solo lo que está entre <body> y </body> para evitar etiquetas anidadas
            if (htmlBody.contains('<body')) {
                htmlBody = htmlBody.substringAfter('>');
                htmlBody = htmlBody.substringBeforeLast('</body>');
            }
            return htmlBody.trim();
        } catch (Exception e) {
            throw new AuraHandledException('Error al procesar la plantilla: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean validatePLPassword(String passwordAttempt) {
        // Obtenemos la contraseña desde el Custom Label
        String correctPassword = System.Label.PL_Access_Password;
        return passwordAttempt == correctPassword;
    }

    @AuraEnabled
    public static void saveTechnicalData(Map<String, Object> data) {
        Id recordId = (Id)data.get('quoteId');
        Id accountId = (Id)data.get('accountId');
        String name = (String)data.get('name');
        String status = (String)data.get('status');
        String intro = (String)data.get('intro');
        String warranty = (String)data.get('warranty');
        String businessLines = (String)data.get('businessLines');
        String technicalSedes = (String)data.get('technicalSedes');
        String lineItemsJson = (String)data.get('lineItems');
        Boolean showIntro = (Boolean)data.get('showIntro');
        Boolean showWarranty = (Boolean)data.get('showWarranty');
        String observacionesPago = (String)data.get('observacionesPago');

        // Objeto para la operación
        Quote q;

        // 1. CASO ACTUALIZACIÓN (Si ya es una Quote)
        if (recordId != null && recordId.getSObjectType().getDescribe().getName() == 'Quote') {
            q = new Quote(
                Id = recordId,
                Name = name,
                Status = status,
                Introduction_Text__c = intro,
                Warranty_Text__c = warranty,
                Business_Lines_Selected__c = businessLines,
                Technical_Sedes__c = technicalSedes,
                Show_Introduction__c = showIntro,
                Show_Warranty__c = showWarranty,
                Description = observacionesPago
            );
            update q;
        } 
        // 2. CASO CREACIÓN
        else {
            Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
            
            q = new Quote(
                Name = name,
                Status = status,
                Introduction_Text__c = intro,
                Warranty_Text__c = warranty,
                Business_Lines_Selected__c = businessLines,
                Technical_Sedes__c = technicalSedes,
                Show_Introduction__c = showIntro,
                Show_Warranty__c = showWarranty,
                Description = observacionesPago,
                ExpirationDate = Date.today().addDays(30),
                Pricebook2Id = standardPricebookId
            );

            // Intentar recuperar datos de cuenta/contacto
            Account acc;
            if (accountId != null) {
                acc = [SELECT Id, Name, (SELECT Id, Name, Phone, Email, MailingStreet, MailingCity, MailingState FROM Contacts LIMIT 1) FROM Account WHERE Id = :accountId];
            }

            if (recordId != null && recordId.getSObjectType().getDescribe().getName() == 'Opportunity') {
                Opportunity opp = [SELECT Id, Pricebook2Id, AccountId FROM Opportunity WHERE Id = :recordId];
                q.OpportunityId = opp.Id;
                if (opp.Pricebook2Id != null) q.Pricebook2Id = opp.Pricebook2Id;
                if (acc == null) {
                    acc = [SELECT Id, Name, (SELECT Id, Name, Phone, Email, MailingStreet, MailingCity, MailingState FROM Contacts LIMIT 1) FROM Account WHERE Id = :opp.AccountId];
                }
            } else if (accountId != null) {
                Opportunity newOpp = new Opportunity(
                    Name = 'Op. Técnica - ' + name, AccountId = accountId,
                    StageName = 'Prospecting', CloseDate = Date.today().addDays(30), Pricebook2Id = standardPricebookId
                );
                insert newOpp;
                q.OpportunityId = newOpp.Id;
            }

            if (acc != null && !acc.Contacts.isEmpty()) {
                Contact mainCon = acc.Contacts[0];
                q.ContactId = mainCon.Id;
                q.Phone = mainCon.Phone;
                q.Email = mainCon.Email;
                q.BillingName = acc.Name;
                q.BillingStreet = mainCon.MailingStreet;
                q.BillingCity = mainCon.MailingCity;
                q.BillingState = mainCon.MailingState;
            }

            insert q;
            recordId = q.Id;
        }

        // PROCESAR PARTIDAS (QuoteLineItems)
        if (String.isNotBlank(lineItemsJson)) {
            List<Object> items = (List<Object>)JSON.deserializeUntyped(lineItemsJson);
            List<QuoteLineItem> linesToInsert = new List<QuoteLineItem>();
            
            // Limpiamos partidas anteriores si el registro ya existía
            delete [SELECT Id FROM QuoteLineItem WHERE QuoteId = :recordId];

            for (Object obj : items) {
                Map<String, Object> item = (Map<String, Object>)obj;
                if (item.get('isSeparator') != null && (Boolean)item.get('isSeparator')) continue;

                Decimal cantidad = Decimal.valueOf(String.valueOf(item.get('cantidad')));
                Decimal unitPrice = Decimal.valueOf(String.valueOf(item.get('importeUnitario')));
                Decimal descuento = item.get('descuento') != null ? Decimal.valueOf(String.valueOf(item.get('descuento'))) : 0;
                String tipoDescuento = (String)item.get('tipoDescuento');

                QuoteLineItem qli = new QuoteLineItem(
                    QuoteId = recordId,
                    PricebookEntryId = (Id)item.get('productId'),
                    Quantity = cantidad,
                    UnitPrice = unitPrice,
                    Description = (String)item.get('detalleTecnico')
                );

                // Si es porcentaje, usamos el campo nativo de Salesforce
                if (tipoDescuento == 'porcentaje' && descuento > 0) {
                    qli.Discount = descuento;
                } 
                // Si es monto fijo, lo manejamos restándolo del UnitPrice para que el TotalPrice sea correcto
                else if (tipoDescuento == 'monto' && descuento > 0) {
                    qli.UnitPrice = unitPrice - (descuento / cantidad);
                }

                linesToInsert.add(qli);
            }
            if (!linesToInsert.isEmpty()) insert linesToInsert;
        }
    }

    @AuraEnabled
    public static Id cloneQuote(Id quoteId, Map<String, Boolean> options) {
        try {
            // 1. Obtener datos del original
            Quote original = [SELECT Id, Name, AccountId, OpportunityId, Pricebook2Id, 
                                     Introduction_Text__c, Warranty_Text__c, Business_Lines_Selected__c, 
                                     Technical_Sedes__c, Show_Introduction__c, Show_Warranty__c,
                                     Description, Phone, Email, BillingName, BillingStreet, BillingCity, BillingState,
                                     (SELECT Id, PricebookEntryId, Quantity, UnitPrice, ListPrice, Discount, Description FROM QuoteLineItems)
                              FROM Quote WHERE Id = :quoteId];

            // 2. Crear el clon
            Quote clone = original.clone(false, true, false, false);
            clone.Name = 'CLON: ' + original.Name;
            clone.Status = 'Draft';
            clone.Source_Quote__c = original.Id; // Vinculación para rastreo
            
            // 3. Aplicar opciones de clonación
            if (options.get('copyTexts') == false) {
                clone.Introduction_Text__c = '';
                clone.Warranty_Text__c = '';
            }
            if (options.get('copySedes') == false) {
                clone.Technical_Sedes__c = '';
            }

            insert clone;

            // 4. Clonar Partidas si se solicitó
            if (options.get('copyLineItems') == true && !original.QuoteLineItems.isEmpty()) {
                List<QuoteLineItem> clonedLines = new List<QuoteLineItem>();
                for (QuoteLineItem oli : original.QuoteLineItems) {
                    QuoteLineItem cli = oli.clone(false, true, false, false);
                    cli.QuoteId = clone.Id;
                    clonedLines.add(cli);
                }
                insert clonedLines;
            }

            return clone.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error al clonar el presupuesto: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Integer getCloneCount(Id quoteId) {
        return [SELECT COUNT() FROM Quote WHERE Source_Quote__c = :quoteId];
    }
}