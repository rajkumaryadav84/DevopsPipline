import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class EnrollModal extends LightningModal {
    @api flowApiName = 'Create_Lead_Screen_Flow';

    handleStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            this.close('finished');
        }
    }
}