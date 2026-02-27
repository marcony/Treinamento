public class LeadRepository {    
    public static void addLead(Lead leadObj) {
        if (!validarCpfCnpj(leadObj.RecordTypeId, leadObj.CPF_CNPJ__c)) {    
            throw new AuraHandledException('CPF ou CNPJ inválido para o tipo de lead informado.');
        }
        insert leadObj;    
    }    
    
    public static void updateLead(Lead leadObj) {
        if (!validarCpfCnpj(leadObj.RecordTypeId, leadObj.CPF_CNPJ__c)) {    
            throw new AuraHandledException('CPF ou CNPJ inválido para o tipo de lead informado.');
        }
        update leadObj; 
    }    
    
    public static Lead getLeadById(Id leadId) {
        return [SELECT Id, RecordTypeId, CPF_CNPJ__c FROM Lead WHERE Id = :leadId LIMIT 1];    
    }    

    public static List<Lead> listAll() {
        return [SELECT Id, RecordTypeId, CPF_CNPJ__c FROM Lead];    
    }    
    
    public static void excluirLeadById(Id leadId) {
        Lead leadObj = getLeadById(leadId);
        if (leadObj != null) {    
            delete leadObj;
        }    
    }   

    public static void validarCpfCnpjEmLote(List<Lead> leads) {
        // Coleta todos os RecordTypeIds presentes nos registros
        Set<Id> recordTypeIds = new Set<Id>();
        for (Lead ldd : leads) {
            if (ldd.RecordTypeId != null) {
                recordTypeIds.add(ldd.RecordTypeId);
            }
        }
        // Busca os RecordTypes e cria um mapa Id -> Name
        Map<Id, RecordType> rtMap = new Map<Id, RecordType>(
            [SELECT Id, Name FROM RecordType WHERE Id IN :recordTypeIds AND SObjectType = 'Lead']
        );
        for (Lead ldd : leads) {
            String tipo = '';
            if (ldd.RecordTypeId != null && rtMap.containsKey(ldd.RecordTypeId)) {
                tipo = rtMap.get(ldd.RecordTypeId).Name; // ou .DeveloperName se preferir
            }
            if (!validarCpfCnpj(tipo, ldd.CPF_CNPJ__c)) {
                ldd.CPF_CNPJ__c.addError('CPF ou CNPJ inválido para o tipo de conta informado.');
            }
        }
    }
    
    private static Boolean validarCpfCnpj(String tipo, String documento) {
        String clean = documento != null ? documento.replaceAll('[^0-9]', '') : '';
        if (tipo == 'PF') {    
            return true; //isValidCPF(clean);
        } else if (tipo == 'PJ') {    
            return false; //isValidCNPJ(clean);
        }
        return false;    
    }    

    private static Boolean isValidCPF(String cpf) {
        if (String.isBlank(cpf) || cpf.length() != 11) return false;

        Boolean todosIguais = true;
        for (Integer i = 1; i < cpf.length(); i++) {
            if (cpf.substring(i, i+1) != cpf.substring(0, 1)) {
                todosIguais = false;
                break;
            }
        }
        if (todosIguais) return false;

        Integer sum = 0;
        for (Integer i = 0; i < 9; i++) {     
            sum += Integer.valueOf(cpf.substring(i, i+1)) * (10 - i);
        }

        Integer firstDigit = Math.mod((sum * 10), 11);
        if (firstDigit == 10) firstDigit = 0;

        if (firstDigit != Integer.valueOf(cpf.substring(9, 10))) return false;

        sum = 0;
        for (Integer i = 0; i < 10; i++) {    
            sum += Integer.valueOf(cpf.substring(i, i+1)) * (11 - i);
        }

        Integer secondDigit = Math.mod((sum * 10), 11);
        if (secondDigit == 10) secondDigit = 0;

        return secondDigit == Integer.valueOf(cpf.substring(10, 11));
    }  

    private static Boolean isValidCNPJ(String cnpj) {
        if (String.isBlank(cnpj) || cnpj.length() != 14) return false;
    
        Boolean todosIguais = true;
        for (Integer i = 1; i < cnpj.length(); i++) {
            if (cnpj.substring(i, i+1) != cnpj.substring(0, 1)) {
                todosIguais = false;
                break;
            }
        }
        if (todosIguais) return false;
    
        Integer[] weights1 = new Integer[]{5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2};
        Integer[] weights2 = new Integer[]{6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2};
    
        Integer sum = 0;
        for (Integer i = 0; i < 12; i++) {    
            sum += Integer.valueOf(cnpj.substring(i, i+1)) * weights1[i];
        }
    
        Integer firstDigit = Math.mod(sum, 11); 
        firstDigit = (firstDigit < 2) ? 0 : 11 - firstDigit;
    
        if (firstDigit != Integer.valueOf(cnpj.substring(12, 13))) return false;
    
        sum = 0;
        for (Integer i = 0; i < 13; i++) {    
            sum += Integer.valueOf(cnpj.substring(i, i+1)) * weights2[i];
        }
    
        Integer secondDigit = Math.mod(sum, 11); 
        secondDigit = (secondDigit < 2) ? 0 : 11 - secondDigit;
    
        return secondDigit == Integer.valueOf(cnpj.substring(13));
    }
}