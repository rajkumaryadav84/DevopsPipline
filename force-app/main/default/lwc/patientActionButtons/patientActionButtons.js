import { LightningElement } from 'lwc';

export default class PatientActionButtons extends LightningElement{

saveDraft(){

this.dispatchEvent(new CustomEvent('savedraft'));

}

submit(){

this.dispatchEvent(new CustomEvent('submitrecord'));

}

}