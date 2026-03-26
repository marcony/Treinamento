public class AccountEmailService {
    
    public static void sendAccountEmails(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return;

        List<Account> accounts = [
            SELECT Id, Name, OwnerId, Owner.Email, EmailParticipantes__c
            FROM Account
            WHERE Id IN :accountIds
        ];

        EmailTemplate template = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'EmailContactReport'
            LIMIT 1
        ];

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        for (Account acc : accounts) {
            List<String> toAddresses = new List<String>();

            // E-mails do campo custom
            if (String.isNotBlank(acc.EmailParticipantes__c)) {
                for (String emailStr : acc.EmailParticipantes__c.split(';')) {
                    String trimmedEmail = emailStr.trim();
                    if (trimmedEmail != '') {
                        toAddresses.add(trimmedEmail);
                    }
                }
            }

            // Fallback: se campo vazio, tenta Owner
            if (toAddresses.isEmpty() && String.isNotBlank(acc.Owner.Email)) {
                toAddresses.add(acc.Owner.Email);
            }

            // Se houver destinatários
            if (!toAddresses.isEmpty()) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(toAddresses);
                email.setTemplateId(template.Id);
                email.setWhatId(acc.Id);
                email.setTargetObjectId(acc.OwnerId);  
                email.setSaveAsActivity(false);

                emailsToSend.add(email);
            }
        }

        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
        }
    }
}
