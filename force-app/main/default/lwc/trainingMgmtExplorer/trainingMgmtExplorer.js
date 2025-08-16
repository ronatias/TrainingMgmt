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

      // NEW: precompute stars, button state, dynamic tile class, and dynamic variant
      this.rows = baseRows.map(r => {
        const n = Math.max(0, Math.min(5, Math.floor(r.rating || 0)));
        const stars = Array.from({ length: n }, (_, i) => i);

        // existing server booleans:
        const already = !!r.alreadyEnrolled;
        const canEnroll = !!r.canEnroll;

        //decide if we show the button:
        // - show when user can enroll OR when already enrolled (to show green disabled)
        const showButton = canEnroll || already;

        //label/disabled + dynamic variant
        const enrollDisabled = already ? true : false;
        const enrollLabel = already ? 'Enrolled' : 'Enroll Me';
        const buttonVariant = already ? 'success' : 'brand-outline'; // <— green when enrolled

        //dynamic tile class (optional visual cue)
        const tileBase = 'tile slds-card slds-p-around_small';
        const tileClass = already ? `${tileBase} tile--enrolled` : tileBase;

        return {
          ...r,
          stars,
          // keep original flags for template logic
          alreadyEnrolled: already,
          canEnroll: canEnroll,
          //UI helpers
          showButton,
          enrollDisabled,
          enrollLabel,
          buttonVariant,
          tileClass
        };
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

    //optimistic UI guard – if already disabled, ignore extra clicks
    const row = this.rows.find(x => x.id === trainingId);
    if (row?.enrollDisabled) {
      return;
    }

    this.loading = true;
    try {
      const res = await enrollMe({ trainingId });
      if (res?.success) {
        this.showToast('Enrolled', res?.message || 'You have been enrolled.', 'success');

        //flip the specific row to "Enrolled" — keep button visible, make it green+disabled
        this.rows = this.rows.map(r => {
          if (r.id === trainingId) {
            const tileBase = 'tile slds-card slds-p-around_small';
            return {
              ...r,
              alreadyEnrolled: true,
              canEnroll: r.canEnroll,            // keep original capability; UI will base on alreadyEnrolled
              showButton: true,                  // show the button in enrolled state
              enrollDisabled: true,              // disable it
              enrollLabel: 'Enrolled',           // label changes
              buttonVariant: 'success',          // <— green style
              tileClass: `${tileBase} tile--enrolled`
            };
          }
          return r;
        });
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
