public with sharing class PdfFileController {
    public class PdfInfoResponse {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public Integer contentSize;
    }

    @AuraEnabled(cacheable=true)
    public static PdfInfoResponse getPdfInfo(Id contentDocumentId) {
        if (contentDocumentId == null) {
            throw new AuraHandledException('Informe um ContentDocumentId valido.');
        }

        try {
            ContentVersion contentVersion = [
                SELECT ContentDocumentId, Id, Title, FileExtension, ContentSize
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                AND IsLatest = true
                LIMIT 1
            ];

            PdfInfoResponse response = new PdfInfoResponse();
            response.contentDocumentId = contentVersion.ContentDocumentId;
            response.contentVersionId = contentVersion.Id;
            response.title = contentVersion.Title;
            response.fileExtension = contentVersion.FileExtension;
            response.contentSize = contentVersion.ContentSize;

            if (response.fileExtension == null || response.fileExtension.toLowerCase() != 'pdf') {
                throw new AuraHandledException('Apenas arquivos PDF sao permitidos.');
            }

            return response;
        } catch (QueryException ex) {
            throw new AuraHandledException('Nao foi possivel localizar o PDF enviado.');
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException('Erro ao obter os metadados do arquivo PDF.');
        }
    }
}
