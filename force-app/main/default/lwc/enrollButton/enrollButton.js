import { LightningElement, api } from 'lwc';
import EnrollModal from 'c/enrollModal';

export default class EnrollButton extends LightningElement {
    @api flowApiName = 'Create_Lead_Screen_Flow';

    async handleClick() {
        await EnrollModal.open({
            size: 'small',
            description: 'Enroll a new Lead',
            flowApiName: this.flowApiName
        });
    }
}