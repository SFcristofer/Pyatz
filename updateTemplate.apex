String updatedHtml = '<table border="0" cellpadding="5" width="600" cellspacing="5" height="400" >\\n' +
'<tr valign="top" height="50" >\\n' +
'<td tEditID="c1r1" style=" background-color:#FFFFFF; bEditID:r3st1; color:#000000; bLabel:main; font-size:12pt; font-family:arial;" aEditID="c1r1" locked="0" >\\n' +
'<![CDATA[]]></td>\\n' +
'</tr>\\n' +
'<tr valign="top" height="300" >\\n' +
'<td tEditID="c1r2" style=" background-color:#FFFFFF; bEditID:r3st1; color:#000000; bLabel:main; font-size:12pt; font-family:arial;" aEditID="c1r2" locked="0" >\\n' +
'<![CDATA[' +
'<p>Equipo, requiero de su apoyo para realizar un levantamiento.</p><br>' +
'<p><b>El cliente solicita se realice:<br>Fecha:<br>Hora:<br>Direcci&oacute;n:&nbsp;{!Account.BillingAddress}</b></p><br>' +
'<p><b>Cliente:&nbsp;{!Account.Razon_Social__c}<br>' +
'Contacto:&nbsp;{!Account.Name}<br>' +
'Tel&eacute;fono:&nbsp;{!Account.Phone}</b></p><br>' +
'<p><b>Tipo: </b><span style="color: rgb(255, 0, 255);">(Servicio/Producto/Ambos)</span><br>' +
'<b>L&iacute;nea de negocio: </b><span style="color: rgb(255, 0, 255);">(Ambiental/HH)</span><br>' +
'<b>Subl&iacute;nea de negocio: </b><span style="color: rgb(255, 0, 255);">(Bioenzim&aacute;tico/grasas/Intima/Aromas...)</span></p><br>' +
'<p><b>Necesidad espec&iacute;fica:<br>Retos:</b></p><br>' +
'<p><b>Fecha requerida para entrega presupuesto: </b><span style="color: rgb(255, 0, 255);">(Fecha)</span></p>' +
']]></td>\\n' +
'</tr>\\n' +
'<tr valign="top" height="50" >\\n' +
'<td tEditID="c1r3" style=" background-color:#FFFFFF; bEditID:r3st1; color:#000000; bLabel:main; font-size:12pt; font-family:arial;" aEditID="c1r3" locked="0" >\\n' +
'<![CDATA[]]></td>\\n' +
'</tr>\\n' +
'</table>';

EmailTemplate template = [SELECT Id, HtmlValue FROM EmailTemplate WHERE Id = '00XV9000001nbqfMAA' LIMIT 1];
template.HtmlValue = updatedHtml;
update template;
