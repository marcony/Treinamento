trigger AccountTrigger on Account (before insert, before update, after insert, after update) {
    
    if (Trigger.isBefore) {
        // Lógica antes do insert/update (ex: validações futuras)
        // Exemplo: AccountRepository.validarCpfCnpjEmLote(Trigger.new);
    }

    if (Trigger.isAfter) {
        List<Id> accountsToEmail = new List<Id>();

        for (Account acc : Trigger.new) {
            if (acc.Enviar_Email__c == true) {
                accountsToEmail.add(acc.Id);
            }
        }

        if (!accountsToEmail.isEmpty()) {
            // Evita chamadas individuais - melhor para desempenho
            AccountEmailService.sendAccountEmails(accountsToEmail);
        }
    }
}