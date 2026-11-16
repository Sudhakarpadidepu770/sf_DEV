import { LightningElement, api, track } from 'lwc';
import searchCustomers from '@salesforce/apex/Customer360Controller.searchCustomers';
import getCustomer360 from '@salesforce/apex/Customer360Controller.getCustomer360';

export default class Customer360View extends LightningElement {
    @api recordId; // auto-populated when placed on an Account record page

    @track searchTerm = '';
    @track searchResults = [];
    @track isSearching = false;
    @track showResults = false;

    @track data;
    @track isLoading = false;
    @track errorMessage = '';
    @track activeTab = 'assets';

    searchTimeout;

    connectedCallback() {
        if (this.recordId) {
            this.loadCustomer(this.recordId);
        }
    }

    get hasData() {
        return !!this.data;
    }

    get showSearch() {
        return !this.recordId;
    }

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        window.clearTimeout(this.searchTimeout);
        if (!this.searchTerm || this.searchTerm.length < 2) {
            this.searchResults = [];
            this.showResults = false;
            return;
        }
        this.searchTimeout = window.setTimeout(() => {
            this.runSearch();
        }, 300);
    }

    async runSearch() {
        this.isSearching = true;
        try {
            const results = await searchCustomers({ searchTerm: this.searchTerm });
            this.searchResults = results;
            this.showResults = true;
        } catch (error) {
            this.searchResults = [];
        } finally {
            this.isSearching = false;
        }
    }

    handleSelectCustomer(event) {
        const accountId = event.currentTarget.dataset.id;
        this.showResults = false;
        this.searchResults = [];
        this.searchTerm = '';
        this.loadCustomer(accountId);
    }

    handleChangeCustomer() {
        this.data = undefined;
        this.searchTerm = '';
    }

    async loadCustomer(accountId) {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const result = await getCustomer360({ accountId });
            if (!result || !result.accountId) {
                this.errorMessage = 'No customer found.';
                this.data = undefined;
            } else {
                this.data = result;
                this.activeTab = 'assets';
            }
        } catch (error) {
            this.errorMessage = 'Could not load this customer right now.';
            this.data = undefined;
        } finally {
            this.isLoading = false;
        }
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    get isAssetsTab() {
        return this.activeTab === 'assets';
    }
    get isCasesTab() {
        return this.activeTab === 'cases';
    }
    get isWorkOrdersTab() {
        return this.activeTab === 'workorders';
    }
    get isAppointmentsTab() {
        return this.activeTab === 'appointments';
    }

    get assetsTabClass() {
        return this.tabClass(this.isAssetsTab);
    }
    get casesTabClass() {
        return this.tabClass(this.isCasesTab);
    }
    get workOrdersTabClass() {
        return this.tabClass(this.isWorkOrdersTab);
    }
    get appointmentsTabClass() {
        return this.tabClass(this.isAppointmentsTab);
    }

    tabClass(isActive) {
        return isActive ? 'tab-item tab-item-active' : 'tab-item';
    }

    get assetsWithBadge() {
        if (!this.data) return [];
        return this.data.assets.map((a) => ({
            ...a,
            warrantyLabel: a.underWarranty ? 'Under Warranty' : 'Out of Warranty',
            warrantyVariant: a.underWarranty ? 'slds-badge_success' : 'slds-badge_inverse'
        }));
    }

    get casesWithBadge() {
        if (!this.data) return [];
        return this.data.cases.map((c) => ({
            ...c,
            statusVariant: c.status === 'Closed' ? 'slds-badge_success' : c.status === 'Escalated' ? 'slds-badge_error' : 'slds-badge_warning'
        }));
    }

    get workOrdersWithBadge() {
        if (!this.data) return [];
        return this.data.workOrders.map((w) => ({
            ...w,
            statusVariant: w.status === 'Completed' || w.status === 'Closed' ? 'slds-badge_success' : 'slds-badge_warning'
        }));
    }

    get appointmentsWithBadge() {
        if (!this.data) return [];
        return this.data.appointments.map((a) => ({
            ...a,
            statusVariant: a.status === 'Completed' ? 'slds-badge_success' : a.status === 'Canceled' ? 'slds-badge_error' : 'slds-badge_warning',
            technicianDisplay: a.technicianName || 'Unassigned'
        }));
    }
}