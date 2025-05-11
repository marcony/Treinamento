public class AccountRepository {    
    public static void addAccount(Account conta) {
        if (!validarCpfCnpj(conta.Tipo__c, conta.CpfCnpj__c)) {    
            throw new AuraHandledException('CPF ou CNPJ inválido para o tipo de conta informado.');
        }insert conta;    
    }    
    
    public static void updateAccount(Account conta) {
        if (!validarCpfCnpj(conta.Tipo__c, conta.CpfCnpj__c)) {    
            throw new AuraHandledException('CPF ou CNPJ inválido para o tipo de conta informado.');
        }
        update conta; 
    }    
    
    public static Account getAccountById(Id contaId) {
        return [SELECT Id, Tipo__c, CpfCnpj__c FROM Account WHERE Id = :contaId LIMIT 1];    
    }    

    public static List<Account> listAll() {
        return [SELECT Id, Tipo__c, CpfCnpj__c FROM Account];    
    }    
    
    public static void excuirAccountById(Id contaId) {
        Account conta = getAccountById(contaId);
        if (conta != null) {    
            delete conta;
        }    
    }   
    
    
    private static Boolean validarCpfCnpj(String tipo, String documento) {
        String clean = documento != null ? documento.replaceAll('[^0-9]', '') : '';
        if (tipo == 'PF') {    
            return isValidCPF(clean);
        } else if (tipo == 'PJ') {    
            return isValidCNPJ(clean);
        }return false;    
    }    

    private static Boolean isValidCPF(String cpf) {
        if (String.isBlank(cpf) || cpf.length() != 11) return false;
    
        // Verifica se todos os dígitos são iguais
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
    
        Integer firstDigit = (sum * 10) % 11;
        if (firstDigit == 10) firstDigit = 0;
    
        if (firstDigit != Integer.valueOf(cpf.substring(9, 10))) return false;
    
        sum = 0;
        for (Integer i = 0; i < 10; i++) {    
            sum += Integer.valueOf(cpf.substring(i, i+1)) * (11 - i);
        }
    
        Integer secondDigit = (sum * 10) % 11;
        if (secondDigit == 10) secondDigit = 0;
    
        return secondDigit == Integer.valueOf(cpf.substring(10));
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
        for (Integer i = 0; i < 12; i++) {    
            sum += Integer.valueOf(cnpj.substring(i, i+1)) * weights1[i];
        }
    
        Integer firstDigit = sum % 11;
        firstDigit = (firstDigit < 2) ? 0 : 11 - firstDigit;
    
        if (firstDigit != Integer.valueOf(cnpj.substring(12, 13))) return false;
    
        sum = 0;
        for (Integer i = 0; i < 13; i++) {    
            sum += Integer.valueOf(cnpj.substring(i, i+1)) * weights2[i];
        }
    
        Integer secondDigit = sum % 11;
        secondDigit = (secondDigit < 2) ? 0 : 11 - secondDigit;
    
        return secondDigit == Integer.valueOf(cnpj.substring(13));
    }
        



}