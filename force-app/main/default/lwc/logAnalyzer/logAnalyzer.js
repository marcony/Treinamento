import { LightningElement } from 'lwc';
import analyzeLog from '@salesforce/apex/LogAnalyzerController.analyzeLog';

export default class LogAnalyzer extends LightningElement {
    logId = '';
    loading = false;
    error = '';
    result = null;

    get isAnalyzeDisabled() {
        return this.loading;
    }

    get hasResult() {
        return this.result !== null;
    }

    get hasEvidence() {
        return this.result && this.result.evidence && this.result.evidence.length > 0;
    }

    get hasFixSteps() {
        return this.result && this.result.fixSteps && this.result.fixSteps.length > 0;
    }

    get hasPrevention() {
        return this.result && this.result.prevention && this.result.prevention.length > 0;
    }

    get hasCode() {
        return this.result && this.result.code;
    }

    get evidenceItems() {
        if (!this.hasEvidence) {
            return [];
        }
        return this.result.evidence.map((item, index) => ({ key: `ev-${index}`, text: item }));
    }

    get fixStepItems() {
        if (!this.hasFixSteps) {
            return [];
        }
        return this.result.fixSteps.map((item, index) => ({ key: `fx-${index}`, text: item }));
    }

    get preventionItems() {
        if (!this.hasPrevention) {
            return [];
        }
        return this.result.prevention.map((item, index) => ({ key: `pv-${index}`, text: item }));
    }

    handleLogIdChange(event) {
        this.logId = event.target.value;
    }

    async handleAnalyze() {
        this.error = '';
        this.result = null;

        if (!this.logId || !this.logId.trim()) {
            this.error = 'Informe um Log Id para analisar.';
            return;
        }

        this.loading = true;
        try {
            const response = await analyzeLog({ logId: this.logId.trim() });
            this.result = {
                rootCause: response?.rootCause || '',
                evidence: response?.evidence || [],
                fixSteps: response?.fixSteps || [],
                code: response?.code || '',
                prevention: response?.prevention || []
            };
        } catch (err) {
            this.error = err?.body?.message || 'Nao foi possivel analisar o log informado.';
        } finally {
            this.loading = false;
        }
    }

    async handleCopyCode() {
        if (!this.hasCode) {
            return;
        }

        try {
            if (navigator?.clipboard?.writeText) {
                await navigator.clipboard.writeText(this.result.code);
                return;
            }
            this.copyWithFallback(this.result.code);
        } catch (e) {
            this.copyWithFallback(this.result.code);
        }
    }

    copyWithFallback(text) {
        const tempTextArea = document.createElement('textarea');
        tempTextArea.value = text;
        this.template.appendChild(tempTextArea);
        tempTextArea.select();
        document.execCommand('copy');
        this.template.removeChild(tempTextArea);
    }
}
