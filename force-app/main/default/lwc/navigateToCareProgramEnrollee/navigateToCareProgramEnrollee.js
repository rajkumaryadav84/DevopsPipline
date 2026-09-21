import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class NavigationAction extends NavigationMixin(LightningElement) {
    // Input property to receive Account Id from Flow
    @api careProgramEnrolleeId;

    // Method executed when Flow invokes this Action
    @api invoke() {
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.careProgramEnrolleeId,
                objectApiName: "CareProgramEnrollee",
                actionName: "view",
            },
        });
    }
}