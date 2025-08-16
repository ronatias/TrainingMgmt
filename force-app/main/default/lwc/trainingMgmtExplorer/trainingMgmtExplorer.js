import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTrainings from '@salesforce/apex/TrainingMgmt_Controller.getTrainings';
import enrollMe from '@salesforce/apex/TrainingMgmt_Controller.enrollMe';

export default class TrainingMgmtExplorer extends LightningElement {
  @track rows = [];
  @track loading = false;

  searchKey = '';
  minRatingStr = '';
  isSuperUser = false; // will be set from Apex response

  connectedCallback() {
    this.refresh();
  }

  get ratingOptions() {
    return [
      { label: 'Any', value: '' },
      { label: '1+', value: '1' },
      { label: '2+', value: '2' },
      { label: '3+', value: '3' },
      { label: '4+', value: '4' },
      { label: '5', value: '5' }
    ];
  }

  handleSearchChange(e) { this.searchKey = e.target.value || ''; }
  handleRatingChange(e) { this.minRatingStr = e.detail.value || ''; }

  async refresh() {
    this.loading = true;
    try {
      const minRating = this.minRatingStr === '' ? null : Number(this.minRatingStr);
      const res = await getTrainings({ searchKey: this.searchKey, minRating });
      const baseRows = res?.rows || [];
      this.rows = baseRows.map(r => {
        const n = Math.max(0, Math.min(5, Math.floor(r.rating || 0)));
        return { ...r, stars: Array.from({ length: n }, (_, i) => i) };
      });
      this.isSuperUser = !!res?.isSuperUser;
    } catch (e) {
      this.showToast('Error loading trainings', this.readError(e), 'error');
    } finally {
      this.loading = false;
    }
  }

  async handleEnroll(evt) {
    const trainingId = evt.currentTarget.dataset.id;
    this.loading = true;
    try {
      const res = await enrollMe({ trainingId });
      if (res?.success) {
        this.showToast('Enrolled', res?.message || 'You have been enrolled.', 'success');
      } else {
        this.showToast('Cannot enroll', res?.message || 'Unknown error', 'warning');
      }
    } catch (e) {
      this.showToast('Error', this.readError(e), 'error');
    } finally {
      this.loading = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  readError(e) {
    if (e?.body?.message) return e.body.message;
    if (e?.body?.pageErrors?.length) return e.body.pageErrors[0].message;
    if (e?.message) return e.message;
    return 'Unexpected error';
  }
}
