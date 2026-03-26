import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import pdfjsResource from '@salesforce/resourceUrl/pdfjs';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PdfReaderLocal extends LightningElement {
    folderName;
    pageCount = 0;
    totalFiles = 0;
    isProcessing = false;
    processedFiles = [];
    pdfJsInitialized = false;
    pdfJsLoading;

    renderedCallback() {
        if (this.pdfJsInitialized || this.pdfJsLoading) {
            return;
        }

        this.pdfJsLoading = Promise.all([
            loadScript(this, pdfjsResource + '/pdf.js')
        ])
            .then(() => {
                // pdfjsLib fica disponível no window após carregar o script
                if (!window.pdfjsLib) {
                    throw new Error('PDF.js não foi carregado corretamente.');
                }

                // ajuste importante para o worker
                window.pdfjsLib.GlobalWorkerOptions.workerSrc =
                    pdfjsResource + '/pdf.worker.js';

                this.pdfJsInitialized = true;
            })
            .catch((error) => {
                this.showError('Erro ao carregar PDF.js', this.normalizeError(error));
            });
    }

    async handleFileChange(event) {
        try {
            const files = Array.from(event.target.files || []);

            if (!files || files.length === 0) {
                return;
            }

            const pdfFiles = files.filter((file) => file.name.toLowerCase().endsWith('.pdf'));

            if (pdfFiles.length === 0) {
                throw new Error('Nenhum arquivo PDF valido foi encontrado na pasta selecionada.');
            }

            this.folderName = this.extractFolderName(pdfFiles[0]);
            this.totalFiles = pdfFiles.length;
            this.pageCount = 0;
            this.processedFiles = [];
            this.isProcessing = true;

            if (!this.pdfJsInitialized) {
                await this.pdfJsLoading;
            }

            const processedFiles = [];

            for (const file of pdfFiles) {
                const filePageCount = await this.readPdfPageCount(file);

                processedFiles.push({
                    name: file.name,
                    path: file.webkitRelativePath || file.name,
                    sizeLabel: this.formatFileSize(file.size),
                    type: file.type || 'application/pdf',
                    pageCount: filePageCount
                });

                this.pageCount += filePageCount;
            }

            this.processedFiles = processedFiles;
        } catch (error) {
            this.pageCount = 0;
            this.totalFiles = 0;
            this.processedFiles = [];
            this.folderName = null;
            this.showError('Erro ao ler PDF', this.normalizeError(error));
        } finally {
            this.isProcessing = false;
        }
    }

    extractFolderName(file) {
        const pathParts = (file.webkitRelativePath || '').split('/').filter(Boolean);
        return pathParts.length > 1 ? pathParts[0] : 'Arquivos selecionados';
    }

    readFileAsArrayBuffer(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = () => resolve(reader.result);
            reader.onerror = () => reject(new Error('Falha ao ler o arquivo.'));
            reader.readAsArrayBuffer(file);
        });
    }

    async readPdfPageCount(file) {
        const arrayBuffer = await this.readFileAsArrayBuffer(file);
        const uint8Array = new Uint8Array(arrayBuffer);
        const loadingTask = window.pdfjsLib.getDocument({ data: uint8Array });
        const pdf = await loadingTask.promise;

        return pdf.numPages;
    }

    formatFileSize(bytes = 0) {
        if (bytes < 1024) {
            return `${bytes} B`;
        }
        if (bytes < 1024 * 1024) {
            return `${(bytes / 1024).toFixed(2)} KB`;
        }
        if (bytes < 1024 * 1024 * 1024) {
            return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
        }
        return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
    }

    get hasFiles() {
        return this.processedFiles.length > 0;
    }

    get pageCountLabel() {
        if (this.isProcessing) {
            return 'Calculando...';
        }

        return this.hasFiles ? this.pageCount : 'Ainda nao calculado';
    }

    normalizeError(error) {
        return error?.message || error?.body?.message || 'Erro desconhecido';
    }

    showError(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: 'error'
            })
        );
    }
}
