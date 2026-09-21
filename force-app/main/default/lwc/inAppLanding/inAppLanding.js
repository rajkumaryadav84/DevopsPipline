import { LightningElement, wire, api, track } from 'lwc';
import getNavigationItems from '@salesforce/apex/GetItems.getPageItems';

export default class InAppLanding extends LightningElement {
    @api app_description;
    @api app_welcome_text;
    @api page_Name;
    
    @wire(getNavigationItems,{pageName:'$page_Name'}) 
    landingItems;

    get pass_false() {
        return false;
    }

    get pass_true() {
        return true;
    }

}