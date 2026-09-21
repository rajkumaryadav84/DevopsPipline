public with sharing class MyAccController {
    public MyAccController() {

    }

    public static List<Account> getAccounts() {
        return [SELECT Id, Name FROM Account LIMIT 10];
    }

    public static List<Contact> getContacts() {
        return [SELECT Id, FirstName, LastName FROM Contact LIMIT 10];
    }

}