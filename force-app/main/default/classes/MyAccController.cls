public with sharing class MyAccController {
    public MyAccController() {

    }

    public static List<Account> getAccounts() {
        return [SELECT Id, Name FROM Account LIMIT 10];
    }
    
}