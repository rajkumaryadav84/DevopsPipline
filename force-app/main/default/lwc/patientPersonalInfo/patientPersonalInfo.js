import { LightningElement } from 'lwc';

export default class PatientPersonalInfo extends LightningElement {

    patient={};

    genderOptions=[

        {label:'Male',value:'Male'},

        {label:'Female',value:'Female'},

        {label:'Other',value:'Other'}

    ];

    handleChange(event){

        this.patient[event.target.name]=event.target.value;

        this.dispatchEvent(

            new CustomEvent(

                'valuechange',

                {

                    detail:{

                        section:'personal',

                        data:this.patient

                    }

                }

            )

        );

    }

}