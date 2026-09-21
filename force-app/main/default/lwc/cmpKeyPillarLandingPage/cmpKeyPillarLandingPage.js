import { LightningElement ,wire, api} from 'lwc';

import getNavigationItems from '@salesforce/apex/GetItems.getPageItems';

export default class CmpSectorLandingPages extends LightningElement {
    @api app_description;
    @api app_welcome_text;
    @api page_Name;
    
    parameterObject = {
        objectName: this.object_Name,
        recordName: this.record_Name
    };

    @wire(getNavigationItems,{pageName:'$page_Name'}) 
    featureRecords;


    get pass_false() {
        return false;
    }

    get pass_true() {
        return true;
    }
}