public class AccountRepository {    
    private static final String TYPE_PF = 'PF';
    private static final String TYPE_PJ = 'PJ';

    public static void addAccount(Account conta) {
        if (!validarCpfCnpjByRecordTypeId(conta.RecordTypeId, conta.CPF_CNPJ__c)) {    
            throw new AuraHandledException('CPF ou CNPJ inválido para o tipo de conta informado.');
        }
        insert conta;    
    }    
    
    public static void updateAccount(Account conta) {
        if (!validarCpfCnpjByRecordTypeId(conta.RecordTypeId, conta.CPF_CNPJ__c)) {    
            throw new AuraHandledException('CPF ou CNPJ inválido para o tipo de conta informado.');
        }
        update conta; 
    }    
    
    public static Account getAccountById(Id contaId) {
        return [SELECT Id, RecordTypeId, CPF_CNPJ__c FROM Account WHERE Id = :contaId LIMIT 1];    
    }    

    public static List<Account> listAll() {
        return [SELECT Id, RecordTypeId, CPF_CNPJ__c FROM Account];    
    }    
    
    public static void excuirAccountById(Id contaId) {
        List<Account> contas = [SELECT Id FROM Account WHERE Id = :contaId LIMIT 1];
        if (!contas.isEmpty()) {    
            delete contas[0];
        }    
    }   

    public static void validarCpfCnpjEmLote(List<Account> contas) {
        // Coleta todos os RecordTypeIds presentes nos registros
        Set<Id> recordTypeIds = new Set<Id>();
        for (Account acc : contas) {
            if (acc.RecordTypeId != null) {
                recordTypeIds.add(acc.RecordTypeId);
            }
        }
        // Busca os RecordTypes e cria um mapa Id -> DeveloperName
        Map<Id, RecordType> rtMap = new Map<Id, RecordType>(
            [SELECT Id, DeveloperName FROM RecordType WHERE Id IN :recordTypeIds AND SObjectType = 'Account']
        );
        for (Account acc : contas) {
            String tipo = '';
            if (acc.RecordTypeId != null && rtMap.containsKey(acc.RecordTypeId)) {
                tipo = rtMap.get(acc.RecordTypeId).DeveloperName;
            }
            if (!validarCpfCnpj(tipo, acc.CPF_CNPJ__c)) {
                acc.CPF_CNPJ__c.addError('CPF ou CNPJ inválido para o tipo de conta informado.');
            }
        }
    }
    
    @TestVisible
    private static Boolean validarCpfCnpjByRecordTypeId(Id recordTypeId, String documento) {
        String tipo = getTipoByRecordTypeId(recordTypeId);
        return validarCpfCnpj(tipo, documento);
    }

    @TestVisible
    private static String getTipoByRecordTypeId(Id recordTypeId) {
        if (recordTypeId == null) {
            return '';
        }

        Schema.RecordTypeInfo rtInfo = Account.SObjectType.getDescribe().getRecordTypeInfosById().get(recordTypeId);
        if (rtInfo == null) {
            return '';
        }
        return rtInfo.getDeveloperName();
    }

    @TestVisible
    private static String normalizeTipo(String tipo) {
        return String.isBlank(tipo) ? '' : tipo.trim().toUpperCase();
    }
    
    @TestVisible
    private static Boolean validarCpfCnpj(String tipo, String documento) {
        String clean = documento != null ? documento.replaceAll('[^0-9]', '') : '';
        String tipoNormalizado = normalizeTipo(tipo);
        if (tipoNormalizado == TYPE_PF) {    
            return isValidCPF(clean);
        } else if (tipoNormalizado == TYPE_PJ) {    
            return isValidCNPJ(clean);
        }return false;    
    }    

    private static Boolean isValidCPF(String cpf) {
        // Verifica formato básico
        if (String.isBlank(cpf) || cpf.length() != 11 || !cpf.isNumeric()) { // Checa se é numérico
            return false;
        }
        
        // Verifica dígitos repetidos (ex.: 000.000.000-00)
        Boolean allSame = true;
        for (Integer i = 1; i < cpf.length(); i++) {
            if (cpf.mid(i, 1) != cpf.mid(0, 1)) {
                allSame = false;
                break;
            }
        }
        if (allSame) return false;
        
        // Cálculo do primeiro dígito verificador
        Integer sum = 0;
        for (Integer i = 0; i < 9; i++) {
            sum += Integer.valueOf(cpf.mid(i, 1)) * (10 - i); 
        }
        Integer firstDigit = Math.mod((sum * 10), 11);
        firstDigit = (firstDigit == 10) ? 0 : firstDigit;
        if (firstDigit != Integer.valueOf(cpf.mid(9, 1))) {
            return false;
        }
        
        // Cálculo do segundo dígito verificador
        sum = 0;
        for (Integer i = 0; i < 10; i++) {
            sum += Integer.valueOf(cpf.mid(i, 1)) * (11 - i);
        }
        Integer secondDigit = Math.mod((sum * 10), 11);
        secondDigit = (secondDigit == 10) ? 0 : secondDigit;
        
        return secondDigit == Integer.valueOf(cpf.mid(10, 1));
    }


    private static Boolean isValidCNPJ(String cnpj) {
        if (String.isBlank(cnpj) || cnpj.length() != 14) return false;

        // Verifica se todos os dígitos são iguais
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
        try {
            for (Integer i = 0; i < 12; i++) {    
                sum += Integer.valueOf(cnpj.substring(i, i+1)) * weights1[i];
            }
        } catch (Exception e) {
            return false; // Caso haja algum caractere não numérico
        }

        Integer firstDigit = Math.mod(sum, 11); 
        firstDigit = (firstDigit < 2) ? 0 : 11 - firstDigit;

        if (firstDigit != Integer.valueOf(cnpj.substring(12, 13))) return false;

        sum = 0;
        try {
            for (Integer i = 0; i < 13; i++) {    
                sum += Integer.valueOf(cnpj.substring(i, i+1)) * weights2[i];
            }
        } catch (Exception e) {
            return false;
        }

        Integer secondDigit = Math.mod(sum, 11); 
        secondDigit = (secondDigit < 2) ? 0 : 11 - secondDigit;

        // substring(13, 14) pega apenas o último dígito
        return secondDigit == Integer.valueOf(cnpj.substring(13, 14));
    }
            



}
