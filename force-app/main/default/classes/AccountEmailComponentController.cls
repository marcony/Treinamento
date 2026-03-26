public class AccountEmailComponentController {
    public Id accountId { get; set; }
    public Account account { 
        get {
            
                account = [
                    SELECT Name, Owner.Name, Rating, Phone, Fax, AccountNumber, Website,
                           TickerSymbol, Type, Ownership, Industry, NumberOfEmployees, AnnualRevenue, Sic,
                           BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                           ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                           CustomerPriority__c, SLA__c, SLAExpirationDate__c, SLASerialNumber__c,
                           NumberofLocations__c, UpsellOpportunity__c, Active__c, CPF_CNPJ__c,Enviar_Email__c,EmailParticipantes__c
                    FROM Account
                    WHERE Id = :accountId
                    LIMIT 1
                ];
            
            return account;
        }
        private set;
    }
}