trigger AccountTrigger on Account (before insert, before update) {

    
     //insert contexto de insert para account
    if (Trigger.isInsert) {
        if (Trigger.isBefore) {
            
        }
    }

    //contexto de update para account
    if (Trigger.isUpdate) {
        if (Trigger.isBefore) {
            
        }
    }


}