(function () {
    'use strict';

    // ─── Selectors ──────────────────────────────────────────────────────────────
    const cityhallApp = document.getElementById('cityhall-app');
    const receiptViewer = document.getElementById('receipt-viewer');
    const terminalApp = document.getElementById('terminal-app');
    const toastContainer = document.getElementById('toast-container');

    // Cityhall
    const chClose = document.getElementById('ch-close');
    const chPageTitle = document.getElementById('ch-page-title');
    const chNavItems = document.querySelectorAll('.ch-nav-item');
    const chPages = document.querySelectorAll('.ch-page');

    // Terminal
    const terminalClose = document.getElementById('terminal-close');
    const terminalFormView = document.getElementById('terminal-form-view');
    const terminalPrintView = document.getElementById('terminal-print-view');
    const terminalDoneView = document.getElementById('terminal-done-view');
    const terminalPaper = document.getElementById('terminal-paper');
    const terminalLed = document.getElementById('terminal-led');
    const printProgressBar = document.getElementById('print-progress-bar');

    // Receipt viewer
    const rvClose = document.getElementById('rv-close');

    // ─── State ──────────────────────────────────────────────────────────────────
    let config = {};
    let permissions = {};
    let currentPage = 'main';

    // ─── NUI Message Handler ────────────────────────────────────────────────────
    window.addEventListener('message', function (event) {
        var data = event.data;
        switch (data.action) {
            case 'openCityHall': openCityHall(data); break;
            case 'closeCityHall': closeCityHall(); break;
            case 'openReceipt': openReceipt(data); break;
            case 'closeReceipt': closeReceipt(); break;
            case 'openTerminal': openTerminal(data); break;
            case 'closeTerminal': closeTerminal(); break;
            case 'vinResult': showVINResult(data.info); break;
            case 'notify': showToast(data.message, data.type || 'inform'); break;
            case 'printDone': onPrintDone(); break;
        }
    });

    // ─── City Hall ──────────────────────────────────────────────────────────────
    var pageTitles = {
        main: 'Üdvözlünk a Városházán',
        insurance: 'Kötelező biztosítás',
        documents: 'Okmányok',
        vin: 'VIN Ellenőrzés'
    };

    function openCityHall(data) {
        if (data.config) config = data.config;
        if (data.permissions) permissions = data.permissions;

        // VIN visibility
        var navVin = document.getElementById('nav-vin');
        if (navVin) {
            if (permissions.vin) navVin.classList.remove('nav-hidden');
            else navVin.classList.add('nav-hidden');
        }

        // Insurance info
        if (config.insurancePrice !== undefined)
            document.getElementById('ins-price').textContent = formatMoney(config.insurancePrice) + ' Ft';
        if (config.insuranceDuration !== undefined)
            document.getElementById('ins-duration').textContent = config.insuranceDuration + ' nap';

        // Docs
        if (config.documents) populateDocuments(config.documents);

        switchPage('main');
        cityhallApp.classList.remove('hidden');
    }

    function closeCityHall() {
        cityhallApp.classList.add('hidden');
        post('closeUI');
    }

    function switchPage(page) {
        currentPage = page;
        chNavItems.forEach(function (item) {
            item.classList.toggle('active', item.getAttribute('data-page') === page);
        });
        chPages.forEach(function (p) { p.classList.remove('active'); });
        var target = document.getElementById('ch-page-' + page);
        if (target) target.classList.add('active');
        chPageTitle.textContent = pageTitles[page] || 'Városháza';
        if (page !== 'vin') document.getElementById('vin-result').classList.add('hidden');
    }

    chNavItems.forEach(function (item) {
        item.addEventListener('click', function (e) {
            e.preventDefault();
            switchPage(this.getAttribute('data-page'));
        });
    });

    chClose.addEventListener('click', closeCityHall);

    // Insurance
    document.getElementById('btn-buy-insurance').addEventListener('click', function () {
        var plate = document.getElementById('ins-plate').value.trim();
        if (!plate) { showToast('Add meg a rendszámot!', 'error'); return; }
        post('buyInsurance', { plate: plate });
        document.getElementById('ins-plate').value = '';
        showToast('Biztosítás kérelem elküldve...', 'inform');
    });

    // Documents
    function populateDocuments(docs) {
        var grid = document.getElementById('ch-docs-grid');
        grid.innerHTML = '';
        docs.forEach(function (doc) {
            var card = document.createElement('div');
            card.className = 'ch-doc-card';
            card.innerHTML =
                '<div class="doc-icon"><i class="fas fa-file-alt"></i></div>' +
                '<div class="doc-title">' + esc(doc.label) + '</div>' +
                '<div class="doc-meta">' + (doc.wait > 0 ? 'Feldolgozás: ' + doc.wait + 's' : 'Azonnal kész') + '</div>' +
                '<div class="doc-price">' + formatMoney(doc.price) + ' Ft</div>';
            card.addEventListener('click', function () {
                post('requestDocument', { docId: doc.id });
                showToast(doc.label + ' igénylés elküldve...', 'inform');
            });
            grid.appendChild(card);
        });
    }

    // VIN
    document.getElementById('btn-vin-check').addEventListener('click', function () {
        var query = document.getElementById('vin-query').value.trim();
        if (!query) { showToast('Add meg a rendszámot!', 'error'); return; }
        post('vinCheck', { query: query });
        showToast('Lekérdezés folyamatban...', 'inform');
    });

    function showVINResult(info) {
        var container = document.getElementById('vin-result');
        var grid = document.getElementById('vin-result-grid');
        grid.innerHTML = '';
        if (!info || (!info.owner && !info.plate && !info.model)) {
            grid.innerHTML = '<div class="ch-result-item" style="grid-column:1/-1;"><div class="res-label">Eredmény</div><div class="res-value">Nem található információ.</div></div>';
            container.classList.remove('hidden');
            return;
        }
        if (info.owner) grid.innerHTML += '<div class="ch-result-item"><div class="res-label">Tulajdonos</div><div class="res-value">' + esc(info.owner) + '</div></div>';
        if (info.plate) grid.innerHTML += '<div class="ch-result-item"><div class="res-label">Rendszám</div><div class="res-value">' + esc(info.plate) + '</div></div>';
        if (info.model) grid.innerHTML += '<div class="ch-result-item"><div class="res-label">Típus</div><div class="res-value">' + esc(info.model) + '</div></div>';
        if (info.insured !== undefined) {
            var cls = info.insured ? 'insured' : 'not-insured';
            var txt = info.insured ? 'Érvényes' : 'Nincs / Lejárt';
            grid.innerHTML += '<div class="ch-result-item"><div class="res-label">Biztosítás</div><div class="res-value ' + cls + '">' + txt + '</div></div>';
        }
        container.classList.remove('hidden');
    }

    // ─── Receipt Viewer ─────────────────────────────────────────────────────────
    function openReceipt(data) {
        var meta = data.metadata || {};
        document.getElementById('rv-seller').textContent = meta.seller || 'Ismeretlen';
        document.getElementById('rv-serial').textContent = meta.serial || '-';
        document.getElementById('rv-date').textContent = meta.date || '-';
        document.getElementById('rv-description').textContent = meta.description || '-';
        document.getElementById('rv-quantity').textContent = (meta.quantity || 1) + ' db';
        document.getElementById('rv-total').textContent = formatMoney(meta.total || 0) + ' Ft';
        receiptViewer.classList.remove('hidden');
    }

    function closeReceipt() {
        receiptViewer.classList.add('hidden');
        post('closeReceipt');
    }

    rvClose.addEventListener('click', closeReceipt);

    // ─── Payment Terminal ───────────────────────────────────────────────────────
    function openTerminal(data) {
        // Reset to form view
        showTerminalView('form');
        terminalPaper.classList.add('hidden');
        terminalPaper.classList.remove('printing');
        terminalLed.className = 'terminal-led active';
        printProgressBar.style.width = '0%';
        // Clear form
        document.getElementById('t-buyer-id').value = '';
        document.getElementById('t-description').value = '';
        document.getElementById('t-quantity').value = '1';
        document.getElementById('t-price').value = '';
        document.getElementById('t-tax').value = '0';
        terminalApp.classList.remove('hidden');
    }

    function closeTerminal() {
        terminalApp.classList.add('hidden');
        post('closeTerminal');
    }

    terminalClose.addEventListener('click', closeTerminal);

    document.getElementById('btn-terminal-print').addEventListener('click', function () {
        var buyerId = parseInt(document.getElementById('t-buyer-id').value);
        var desc = document.getElementById('t-description').value.trim();
        var qty = parseInt(document.getElementById('t-quantity').value) || 1;
        var price = parseInt(document.getElementById('t-price').value);
        var tax = parseInt(document.getElementById('t-tax').value) || 0;

        if (!buyerId || !desc || !price) {
            showToast('Minden mező kitöltése kötelező!', 'error');
            return;
        }

        // Switch to print view
        showTerminalView('print');
        terminalLed.className = 'terminal-led printing';

        // Start progress animation
        var progress = 0;
        var interval = setInterval(function () {
            progress += 2;
            printProgressBar.style.width = progress + '%';
            if (progress >= 100) {
                clearInterval(interval);
            }
        }, 50);

        // Show paper coming out
        setTimeout(function () {
            terminalPaper.classList.remove('hidden');
            setTimeout(function () {
                terminalPaper.classList.add('printing');
            }, 50);
        }, 1000);

        // Send to server
        post('issueReceipt', {
            targetId: buyerId,
            description: desc,
            quantity: qty,
            unitPrice: price,
            taxPercent: tax
        });
    });

    function onPrintDone() {
        // Show done view after a small delay
        setTimeout(function () {
            showTerminalView('done');
            terminalLed.className = 'terminal-led active';
            // Auto close after 3 seconds
            setTimeout(function () {
                closeTerminal();
            }, 3000);
        }, 500);
    }

    function showTerminalView(view) {
        terminalFormView.classList.remove('active');
        terminalPrintView.classList.remove('active');
        terminalDoneView.classList.remove('active');
        if (view === 'form') terminalFormView.classList.add('active');
        else if (view === 'print') terminalPrintView.classList.add('active');
        else if (view === 'done') terminalDoneView.classList.add('active');
    }

    // ─── Escape Key ─────────────────────────────────────────────────────────────
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            if (!cityhallApp.classList.contains('hidden')) closeCityHall();
            else if (!receiptViewer.classList.contains('hidden')) closeReceipt();
            else if (!terminalApp.classList.contains('hidden')) closeTerminal();
        }
    });

    // ─── Helpers ────────────────────────────────────────────────────────────────
    function post(name, data) {
        fetch('https://realrpg_cityhall/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        }).catch(function () {});
    }

    function formatMoney(amount) {
        return amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    }

    function esc(text) {
        if (!text) return '';
        var d = document.createElement('div');
        d.appendChild(document.createTextNode(text));
        return d.innerHTML;
    }

    function showToast(message, type) {
        type = type || 'inform';
        var toast = document.createElement('div');
        toast.className = 'toast ' + type;
        var icon = 'fa-info-circle';
        if (type === 'success') icon = 'fa-check-circle';
        else if (type === 'error') icon = 'fa-exclamation-circle';
        toast.innerHTML = '<i class="fas ' + icon + '"></i><span>' + esc(message) + '</span>';
        toastContainer.appendChild(toast);
        setTimeout(function () {
            toast.style.animation = 'toastOut .3s ease forwards';
            setTimeout(function () { if (toast.parentNode) toast.parentNode.removeChild(toast); }, 300);
        }, 4000);
    }

})();
