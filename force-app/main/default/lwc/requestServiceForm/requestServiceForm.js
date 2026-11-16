import { LightningElement, track } from 'lwc';
import submitServiceRequest from '@salesforce/apex/PublicServiceRequestController.submitServiceRequest';
import attachPhotoToCase from '@salesforce/apex/PublicServiceRequestController.attachPhotoToCase';

const SERVICE_CATEGORY_OPTIONS = [
    { label: 'Television', value: 'Television' },
    { label: 'Air Conditioner', value: 'Air Conditioner' },
    { label: 'Refrigerator', value: 'Refrigerator' },
    { label: 'Washing Machine', value: 'Washing Machine' },
    { label: 'Laptop', value: 'Laptop' },
    { label: 'Printer', value: 'Printer' },
    { label: 'Microwave', value: 'Microwave' },
    { label: 'Electrical', value: 'Electrical' },
    { label: 'Installation', value: 'Installation' },
    { label: 'Maintenance', value: 'Maintenance' }
];

const TIME_WINDOW_OPTIONS = [
    { label: 'Morning (9 AM - 12 PM)', value: 'Morning (9 AM - 12 PM)' },
    { label: 'Afternoon (12 PM - 4 PM)', value: 'Afternoon (12 PM - 4 PM)' },
    { label: 'Evening (4 PM - 7 PM)', value: 'Evening (4 PM - 7 PM)' }
];

const PRIORITY_OPTIONS = [
    { label: 'Low', value: 'Low' },
    { label: 'Medium', value: 'Medium' },
    { label: 'High', value: 'High' }
];

const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024;

export default class RequestServiceForm extends LightningElement {
    serviceCategoryOptions = SERVICE_CATEGORY_OPTIONS;
    timeWindowOptions = TIME_WINDOW_OPTIONS;
    priorityOptions = PRIORITY_OPTIONS;

    @track customerName = '';
    @track mobile = '';
    @track email = '';
    @track address = '';
    @track serviceCategory = '';
    @track product = '';
    @track problemDescription = '';
    @track preferredDate = '';
    @track preferredTimeWindow = '';
    @track priority = 'Medium';

    selectedFile;
    fileError = '';

    @track isSubmitting = false;
    @track submitted = false;
    @track errorMessage = '';
    @track confirmationCaseNumber = '';

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    handleFileChange(event) {
        const file = event.target.files && event.target.files[0];
        this.fileError = '';
        if (!file) {
            this.selectedFile = undefined;
            return;
        }
        const lowerName = file.name.toLowerCase();
        const allowedExt = ['.jpg', '.jpeg', '.png', '.pdf'];
        const validExt = allowedExt.some((ext) => lowerName.endsWith(ext));
        if (!validExt) {
            this.fileError = 'Only JPG, PNG, or PDF files are allowed.';
            this.selectedFile = undefined;
            return;
        }
        if (file.size > MAX_FILE_SIZE_BYTES) {
            this.fileError = 'File is too large. Maximum size is 5 MB.';
            this.selectedFile = undefined;
            return;
        }
        this.selectedFile = file;
    }

    get isFormInvalid() {
        return (
            !this.customerName ||
            !this.serviceCategory ||
            !this.problemDescription ||
            (!this.mobile && !this.email)
        );
    }

    async handleSubmit() {
        this.errorMessage = '';
        if (this.isFormInvalid) {
            this.errorMessage = 'Please fill in your name, at least one contact method, service type, and problem description.';
            return;
        }

        this.isSubmitting = true;
        try {
            const result = await submitServiceRequest({
                input: {
                    customerName: this.customerName,
                    mobile: this.mobile,
                    email: this.email,
                    address: this.address,
                    serviceCategory: this.serviceCategory,
                    product: this.product,
                    problemDescription: this.problemDescription,
                    preferredDate: this.preferredDate,
                    preferredTimeWindow: this.preferredTimeWindow,
                    priority: this.priority
                }
            });

            if (!result.success) {
                this.errorMessage = result.message;
                this.isSubmitting = false;
                return;
            }

            if (this.selectedFile) {
                await this.uploadSelectedFile(result.caseId);
            }

            this.confirmationCaseNumber = result.caseNumber;
            this.submitted = true;
        } catch (error) {
            this.errorMessage = 'Something went wrong submitting your request. Please try again.';
        } finally {
            this.isSubmitting = false;
        }
    }

    uploadSelectedFile(caseId) {
        return new Promise((resolve) => {
            const reader = new FileReader();
            reader.onload = async () => {
                const base64 = reader.result.split(',')[1];
                try {
                    await attachPhotoToCase({
                        caseId,
                        fileName: this.selectedFile.name,
                        base64Data: base64
                    });
                } catch (error) {
                    // Non-fatal: the Case itself was already created successfully.
                }
                resolve();
            };
            reader.onerror = () => resolve();
            reader.readAsDataURL(this.selectedFile);
        });
    }

    handleSubmitAnother() {
        this.customerName = '';
        this.mobile = '';
        this.email = '';
        this.address = '';
        this.serviceCategory = '';
        this.product = '';
        this.problemDescription = '';
        this.preferredDate = '';
        this.preferredTimeWindow = '';
        this.priority = 'Medium';
        this.selectedFile = undefined;
        this.fileError = '';
        this.submitted = false;
        this.confirmationCaseNumber = '';
    }
}