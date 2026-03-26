trigger LeadTrigger on Lead (before insert, before update) {
    

    //insert contexto de insert
    if (Trigger.isInsert) {
        if (Trigger.isBefore) {
            
        }
    }

    //contexto de update
    if (Trigger.isUpdate) {
        if (Trigger.isBefore) {
            
        }
    }


}