// RealRPG Városháza NUI - app.js

(function () {
    'use strict';

    const app = document.getElementById('app');
    const closeBtn = document.getElementById('close-btn');
    const pageTitle = document.getElementById('page-title');
    const navItems = document.querySelectorAll('.nav-item');
    const pages = document.querySelectorAll('.page');

    // State
    let currentPage = 'main';
    let config = {};
    let permissions = { fines: false, vin: false, receipt: false };

    // ─── NUI Message Handler ────────────────────────────────────────────────────

    window.addEventListener('message', function (event) {
        const data = event.data;

        switch (data.action) {
            case 'open':
                openUI(data);
                break;
            case 'close':
                closeUI();
                break;
            case 'vinResult':
                showVINResult(data.info);
                break;
            case 'notify':
                showToast(data.message, data.type || 'inform');
                break;
            case 'documentReady':
                showToast('Okmány elkészült: ' + (data.item || ''), 'success');
                break;
        }
    });

    // ─── Open / Close ───────────────────────────────────────────────────────────

    function openUI(data) {
        // Store config and permissions
        if (data.config) config = data.config;
        if (data.permissions) permissions = data.permissions;

        // Show/hide nav items based on permissions
        toggleNavVisibility('nav-fines', permissions.fines);
        toggleNavVisibility('nav-vin', permissions.vin);
        toggleNavVisibility('nav-receipt', permissions.receipt);

        // Set insurance info from config
        if (config.insurancePrice !== undefined) {
            document.getElementById('insurance-price').textContent = formatMoney(config.insurancePrice) + ' Ft';
        }
        if (config.insuranceDuration !== undefined) {
            document.getElementById('insurance-duration').textContent = config.insuranceDuration + ' nap';
        }

        // Populate documents
        if (config.documents) {
            populateDocuments(config.documents);
        }

        // Reset to main page
        switchPage('main');

        // Show app
        app.classList.remove('hidden');
    }

    function closeUI() {
        app.classList.add('hidden');
        fetch('https://realrpg_cityhall/closeUI', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    }

    function toggleNavVisibility(id, show) {
        const el = document.getElementById(id);
        if (el) {
            if (show) {
                el.classList.remove('nav-hidden');
            } else {
                el.classList.add('nav-hidden');
            }
        }
    }

    // ─── Navigation ─────────────────────────────────────────────────────────────

    const pageTitles = {
        main: 'Üdvözlünk a Városházán',
        insurance: 'Kötelező biztosítás',
        documents: 'Okmányok',
        fines: 'Bírságok & Számlák',
        vin: 'VIN Ellenőrzés',
        receipt: 'Nyugta kiállítása'
    };

    navItems.forEach(function (item) {
        item.addEventListener('click', function (e) {
            e.preventDefault();
            const page = this.getAttribute('data-page');
            switchPage(page);
        });
    });

    function switchPage(page) {
        currentPage = page;

        // Update nav active state
        navItems.forEach(function (item) {
            item.classList.remove('active');
            if (item.getAttribute('data-page') === page) {
                item.classList.add('active');
            }
        });

        // Update pages
        pages.forEach(function (p) {
            p.classList.remove('active');
        });
        const target = document.getElementById('page-' + page);
        if (target) target.classList.add('active');

        // Update title
        pageTitle.textContent = pageTitles[page] || 'Városháza';

        // Hide VIN result when switching pages
        if (page !== 'vin') {
            document.getElementById('vin-result').classList.add('hidden');
        }
    }

    // ─── Tabs ───────────────────────────────────────────────────────────────────

    document.querySelectorAll('.tab').forEach(function (tab) {
        tab.addEventListener('click', function () {
            const tabId = this.getAttribute('data-tab');
            const parent = this.closest('.page');

            // Update tab buttons
            parent.querySelectorAll('.tab').forEach(function (t) { t.classList.remove('active'); });
            this.classList.add('active');

            // Update tab content
            parent.querySelectorAll('.tab-content').forEach(function (tc) { tc.classList.remove('active'); });
            const content = document.getElementById(tabId);
            if (content) content.classList.add('active');
        });
    });

    // ─── Close Button & Escape Key ─────────────────────────────────────────────

    closeBtn.addEventListener('click', closeUI);

    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            closeUI();
        }
    });

    // ─── Insurance ──────────────────────────────────────────────────────────────

    document.getElementById('btn-buy-insurance').addEventListener('click', function () {
        const plate = document.getElementById('insurance-plate').value.trim();
        if (!plate) {
            showToast('Add meg a rendszámot!', 'error');
            return;
        }
        fetch('https://realrpg_cityhall/buyInsurance', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ plate: plate })
        });
        document.getElementById('insurance-plate').value = '';
        showToast('Biztosítás kérelem elküldve...', 'inform');
    });

    // ─── Documents ──────────────────────────────────────────────────────────────

    function populateDocuments(docs) {
        const grid = document.getElementById('documents-grid');
        grid.innerHTML = '';

        docs.forEach(function (doc) {
            const card = document.createElement('div');
            card.className = 'doc-card';
            card.innerHTML = 
                '<div class="doc-icon"><i class="fas fa-file-alt"></i></div>' +
                '<div class="doc-title">' + escapeHtml(doc.label) + '</div>' +
                '<div class="doc-meta">' + (doc.wait > 0 ? 'Feldolgozás: ' + doc.wait + 's' : 'Azonnal kész') + '</div>' +
                '<div class="doc-price">' + formatMoney(doc.price) + ' Ft</div>';

            card.addEventListener('click', function () {
                fetch('https://realrpg_cityhall/requestDocument', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ docId: doc.id })
                });
                showToast(doc.label + ' igénylés elküldve...', 'inform');
            });

            grid.appendChild(card);
        });
    }

    // ─── Fines ──────────────────────────────────────────────────────────────────

    document.getElementById('btn-issue-fine').addEventListener('click', function () {
        const targetId = parseInt(document.getElementById('fine-target').value);
        const desc = document.getElementById('fine-desc').value.trim();
        const amount = parseInt(document.getElementById('fine-amount').value);
        const due = parseInt(document.getElementById('fine-due').value) || 0;

        if (!targetId || !desc || !amount) {
            showToast('Minden mező kitöltése kötelező!', 'error');
            return;
        }

        fetch('https://realrpg_cityhall/issueFine', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                targetId: targetId,
                description: desc,
                amount: amount,
                dueDays: due
            })
        });

        // Clear form
        document.getElementById('fine-target').value = '';
        document.getElementById('fine-desc').value = '';
        document.getElementById('fine-amount').value = '';
        document.getElementById('fine-due').value = '';
        showToast('Bírság kiállítás elküldve...', 'inform');
    });

    // ─── Invoices ───────────────────────────────────────────────────────────────

    document.getElementById('btn-issue-invoice').addEventListener('click', function () {
        const targetId = parseInt(document.getElementById('invoice-target').value);
        const desc = document.getElementById('invoice-desc').value.trim();
        const qty = parseInt(document.getElementById('invoice-qty').value) || 1;
        const price = parseInt(document.getElementById('invoice-price').value);
        const tax = parseInt(document.getElementById('invoice-tax').value) || 0;

        if (!targetId || !desc || !price) {
            showToast('Minden mező kitöltése kötelező!', 'error');
            return;
        }

        fetch('https://realrpg_cityhall/issueInvoice', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                targetId: targetId,
                description: desc,
                quantity: qty,
                unitPrice: price,
                taxPercent: tax
            })
        });

        // Clear form
        document.getElementById('invoice-target').value = '';
        document.getElementById('invoice-desc').value = '';
        document.getElementById('invoice-qty').value = '1';
        document.getElementById('invoice-price').value = '';
        document.getElementById('invoice-tax').value = '0';
        showToast('Számla kiállítás elküldve...', 'inform');
    });

    // ─── VIN Check ──────────────────────────────────────────────────────────────

    document.getElementById('btn-vin-check').addEventListener('click', function () {
        const query = document.getElementById('vin-query').value.trim();
        if (!query) {
            showToast('Add meg a rendszámot vagy VIN számot!', 'error');
            return;
        }

        fetch('https://realrpg_cityhall/vinCheck', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query: query })
        });
        showToast('Lekérdezés folyamatban...', 'inform');
    });

    function showVINResult(info) {
        const container = document.getElementById('vin-result');
        const grid = document.getElementById('vin-result-grid');
        grid.innerHTML = '';

        if (!info || (!info.owner && !info.plate && !info.model)) {
            grid.innerHTML = '<div class="result-item" style="grid-column: 1/-1;"><div class="result-label">Eredmény</div><div class="result-value">Nem található információ.</div></div>';
            container.classList.remove('hidden');
            return;
        }

        if (info.owner) {
            grid.innerHTML += '<div class="result-item"><div class="result-label">Tulajdonos</div><div class="result-value">' + escapeHtml(info.owner) + '</div></div>';
        }
        if (info.plate) {
            grid.innerHTML += '<div class="result-item"><div class="result-label">Rendszám</div><div class="result-value">' + escapeHtml(info.plate) + '</div></div>';
        }
        if (info.model) {
            grid.innerHTML += '<div class="result-item"><div class="result-label">Típus</div><div class="result-value">' + escapeHtml(info.model) + '</div></div>';
        }
        if (info.insured !== undefined) {
            var insuredClass = info.insured ? 'insured' : 'not-insured';
            var insuredText = info.insured ? 'Érvényes' : 'Nincs / Lejárt';
            grid.innerHTML += '<div class="result-item"><div class="result-label">Biztosítás</div><div class="result-value ' + insuredClass + '">' + insuredText + '</div></div>';
        }

        container.classList.remove('hidden');
    }

    // ─── Receipt ────────────────────────────────────────────────────────────────

    document.getElementById('btn-issue-receipt').addEventListener('click', function () {
        const targetId = parseInt(document.getElementById('receipt-target').value);
        const desc = document.getElementById('receipt-desc').value.trim();
        const qty = parseInt(document.getElementById('receipt-qty').value) || 1;
        const price = parseInt(document.getElementById('receipt-price').value);
        const tax = parseInt(document.getElementById('receipt-tax').value) || 0;

        if (!targetId || !desc || !price) {
            showToast('Minden mező kitöltése kötelező!', 'error');
            return;
        }

        fetch('https://realrpg_cityhall/issueReceipt', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                targetId: targetId,
                description: desc,
                quantity: qty,
                unitPrice: price,
                taxPercent: tax
            })
        });

        // Clear form
        document.getElementById('receipt-target').value = '';
        document.getElementById('receipt-desc').value = '';
        document.getElementById('receipt-qty').value = '1';
        document.getElementById('receipt-price').value = '';
        document.getElementById('receipt-tax').value = '0';
        showToast('Nyugta kiállítás elküldve...', 'inform');
    });

    // ─── Toast Notifications ────────────────────────────────────────────────────

    function showToast(message, type) {
        type = type || 'inform';
        var toast = document.createElement('div');
        toast.className = 'toast ' + type;

        var icon = 'fa-info-circle';
        if (type === 'success') icon = 'fa-check-circle';
        else if (type === 'error') icon = 'fa-exclamation-circle';

        toast.innerHTML = '<i class="fas ' + icon + '"></i><span>' + escapeHtml(message) + '</span>';
        document.body.appendChild(toast);

        setTimeout(function () {
            toast.style.animation = 'toastOut 0.3s ease forwards';
            setTimeout(function () {
                if (toast.parentNode) toast.parentNode.removeChild(toast);
            }, 300);
        }, 4000);
    }

    // ─── Helpers ────────────────────────────────────────────────────────────────

    function formatMoney(amount) {
        return amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    }

    function escapeHtml(text) {
        if (!text) return '';
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(text));
        return div.innerHTML;
    }

})();
