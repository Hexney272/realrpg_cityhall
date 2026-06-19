(function () {
    'use strict';
    var cityhallApp = document.getElementById('cityhall-app');
    var receiptViewer = document.getElementById('receipt-viewer');
    var terminalApp = document.getElementById('terminal-app');
    var toastContainer = document.getElementById('toast-container');
    var chClose = document.getElementById('ch-close');
    var chPageTitle = document.getElementById('ch-page-title');
    var chNavItems = document.querySelectorAll('.ch-nav-item');
    var chPages = document.querySelectorAll('.ch-page');
    var terminalClose = document.getElementById('terminal-close');
    var rvClose = document.getElementById('rv-close');
    var config = {};
    var permissions = {};

    // Ticket & Invoice elements
    var ticketApp = document.getElementById('ticket-app');
    var ticketClose = document.getElementById('ticket-close');
    var ticketSubmit = document.getElementById('ticket-submit');
    var ticketViewer = document.getElementById('ticket-viewer');
    var tvClose = document.getElementById('tv-close');
    var tvPayCash = document.getElementById('tv-pay-cash');
    var tvPayBank = document.getElementById('tv-pay-bank');
    var invoiceApp = document.getElementById('invoice-app');
    var invoiceClose = document.getElementById('invoice-close');
    var invoiceSubmit = document.getElementById('invoice-submit');
    var invoiceSignature = document.getElementById('invoice-signature');
    var invoiceViewer = document.getElementById('invoice-viewer');
    var ivClose = document.getElementById('iv-close');
    var ivAccept = document.getElementById('iv-accept');
    var ivReject = document.getElementById('iv-reject');

    window.addEventListener('message', function (event) {
        var data = event.data;
        switch (data.action) {
            case 'openCityHall': openCityHall(data); break;
            case 'openReceipt': openReceipt(data); break;
            case 'openTerminal': openTerminal(); break;
            case 'vinResult': showVINResult(data.info); break;
            case 'notify': showToast(data.message, data.type); break;
            case 'printDone': onPrintDone(); break;
            case 'openTicket': openTicket(data); break;
            case 'openTicketViewer': openTicketViewer(data); break;
            case 'openInvoice': openInvoice(data); break;
            case 'openInvoiceViewer': openInvoiceViewer(data); break;
        }
    });


    // ═══ CITY HALL ═══
    var pageTitles = { main:'Üdvözlünk a Városházán', insurance:'Kötelező biztosítás', documents:'Okmányok', vin:'VIN Ellenőrzés' };

    function openCityHall(data) {
        if (data.config) config = data.config;
        if (data.permissions) permissions = data.permissions;
        var navVin = document.getElementById('nav-vin');
        if (navVin) navVin.classList.toggle('nav-hidden', !permissions.vin);
        if (config.insurancePrice !== undefined) document.getElementById('ins-price').textContent = fmt(config.insurancePrice) + ' Ft';
        if (config.insuranceDuration !== undefined) document.getElementById('ins-duration').textContent = config.insuranceDuration + ' nap';
        if (config.documents) populateDocuments(config.documents);
        switchPage('main');
        cityhallApp.classList.remove('hidden');
    }

    function closeCityHall() { cityhallApp.classList.add('hidden'); post('closeUI'); }

    function switchPage(page) {
        chNavItems.forEach(function(i){ i.classList.toggle('active', i.getAttribute('data-page')===page); });
        chPages.forEach(function(p){ p.classList.remove('active'); });
        var t = document.getElementById('ch-page-'+page);
        if(t) t.classList.add('active');
        chPageTitle.textContent = pageTitles[page] || 'Városháza';
        if(page!=='vin') document.getElementById('vin-result').classList.add('hidden');
    }

    chNavItems.forEach(function(i){ i.addEventListener('click', function(e){ e.preventDefault(); switchPage(this.getAttribute('data-page')); }); });
    chClose.addEventListener('click', closeCityHall);

    document.getElementById('btn-buy-insurance').addEventListener('click', function(){
        var plate = document.getElementById('ins-plate').value.trim();
        if(!plate){ showToast('Add meg a rendszámot!','error'); return; }
        post('buyInsurance',{plate:plate});
        document.getElementById('ins-plate').value='';
        showToast('Biztosítás kérelem elküldve...','inform');
    });

    function populateDocuments(docs){
        var grid = document.getElementById('ch-docs-grid'); grid.innerHTML='';
        docs.forEach(function(doc){
            var card = document.createElement('div'); card.className='ch-doc-card';
            card.innerHTML='<div class="doc-icon"><i class="fas fa-file-alt"></i></div><div class="doc-title">'+esc(doc.label)+'</div><div class="doc-meta">'+(doc.wait>0?'Feldolgozás: '+doc.wait+'s':'Azonnal kész')+'</div><div class="doc-price">'+fmt(doc.price)+' Ft</div>';
            card.addEventListener('click', function(){ post('requestDocument',{docId:doc.id}); showToast(doc.label+' igénylés elküldve...','inform'); });
            grid.appendChild(card);
        });
    }

    document.getElementById('btn-vin-check').addEventListener('click', function(){
        var q = document.getElementById('vin-query').value.trim();
        if(!q){ showToast('Add meg a rendszámot!','error'); return; }
        post('vinCheck',{query:q}); showToast('Lekérdezés...','inform');
    });

    function showVINResult(info){
        var c = document.getElementById('vin-result'), g = document.getElementById('vin-result-grid'); g.innerHTML='';
        if(!info||(!info.owner&&!info.plate&&!info.model)){ g.innerHTML='<div class="ch-result-item" style="grid-column:1/-1"><div class="res-label">Eredmény</div><div class="res-value">Nem található.</div></div>'; c.classList.remove('hidden'); return; }
        if(info.owner) g.innerHTML+='<div class="ch-result-item"><div class="res-label">Tulajdonos</div><div class="res-value">'+esc(info.owner)+'</div></div>';
        if(info.plate) g.innerHTML+='<div class="ch-result-item"><div class="res-label">Rendszám</div><div class="res-value">'+esc(info.plate)+'</div></div>';
        if(info.model) g.innerHTML+='<div class="ch-result-item"><div class="res-label">Típus</div><div class="res-value">'+esc(info.model)+'</div></div>';
        if(info.insured!==undefined){ var cls=info.insured?'insured':'not-insured'; g.innerHTML+='<div class="ch-result-item"><div class="res-label">Biztosítás</div><div class="res-value '+cls+'">'+(info.insured?'Érvényes':'Nincs / Lejárt')+'</div></div>'; }
        c.classList.remove('hidden');
    }


    // ═══ RECEIPT VIEWER ═══
    function openReceipt(data){
        var m = data.metadata||{};
        document.getElementById('rv-seller').textContent = m.seller||'Ismeretlen';
        document.getElementById('rv-serial').textContent = m.serial||'-';
        document.getElementById('rv-date').textContent = m.date||'-';
        document.getElementById('rv-description').textContent = m.description||'-';
        document.getElementById('rv-quantity').textContent = (m.quantity||1)+' db';
        document.getElementById('rv-total').textContent = fmt(m.total||0)+' Ft';
        receiptViewer.classList.remove('hidden');
    }
    function closeReceipt(){ receiptViewer.classList.add('hidden'); post('closeReceipt'); }
    rvClose.addEventListener('click', closeReceipt);

    // ═══ TERMINAL ═══
    var printData = {};

    function openTerminal(){
        showTermView('form');
        document.getElementById('terminal-paper').classList.add('hidden');
        document.getElementById('terminal-paper').classList.remove('printing');
        document.getElementById('terminal-led').className = 'pos-led active';
        document.getElementById('print-progress-bar').style.width = '0%';
        document.getElementById('t-buyer-id').value='';
        document.getElementById('t-description').value='';
        document.getElementById('t-quantity').value='1';
        document.getElementById('t-price').value='';
        document.getElementById('t-tax').value='0';
        terminalApp.classList.remove('hidden');
    }

    function closeTerminal(){ terminalApp.classList.add('hidden'); post('closeTerminal'); }
    terminalClose.addEventListener('click', closeTerminal);

    document.getElementById('btn-terminal-print').addEventListener('click', function(){
        var buyerId = parseInt(document.getElementById('t-buyer-id').value);
        var desc = document.getElementById('t-description').value.trim();
        var qty = parseInt(document.getElementById('t-quantity').value)||1;
        var price = parseInt(document.getElementById('t-price').value);
        var tax = parseInt(document.getElementById('t-tax').value)||0;
        if(!buyerId||!desc||!price){ showToast('Minden mező kitöltése kötelező!','error'); return; }

        // Calculate total for paper display
        var subtotal = qty * price;
        var taxAmt = Math.floor(subtotal * tax / 100);
        var total = subtotal + taxAmt;

        // Fill print paper with data
        document.getElementById('print-desc').textContent = desc;
        document.getElementById('print-qty').textContent = qty + ' db';
        document.getElementById('print-tax').textContent = tax + '%';
        document.getElementById('print-total').textContent = fmt(total) + ' Ft';

        // Switch to printing view
        showTermView('print');
        document.getElementById('terminal-led').className = 'pos-led printing';

        // Progress animation
        var progress = 0;
        var iv = setInterval(function(){
            progress += 2;
            document.getElementById('print-progress-bar').style.width = progress+'%';
            if(progress>=100) clearInterval(iv);
        }, 50);

        // Show paper coming out with data on it
        setTimeout(function(){
            var paper = document.getElementById('terminal-paper');
            paper.classList.remove('hidden');
            setTimeout(function(){ paper.classList.add('printing'); }, 50);
        }, 800);

        // Send to server
        post('issueReceipt',{ targetId:buyerId, description:desc, quantity:qty, unitPrice:price, taxPercent:tax });
    });

    function onPrintDone(){
        setTimeout(function(){
            showTermView('done');
            document.getElementById('terminal-led').className = 'pos-led active';
            setTimeout(closeTerminal, 3000);
        }, 500);
    }

    function showTermView(v){
        document.getElementById('terminal-form-view').classList.remove('active');
        document.getElementById('terminal-print-view').classList.remove('active');
        document.getElementById('terminal-done-view').classList.remove('active');
        document.getElementById('terminal-'+v+'-view').classList.add('active');
    }

    // ═══ TICKET & INVOICE ═══

    // Ticket type toggles
    var ticketTypeTicketBtn = document.getElementById('ticket-type-ticket');
    var ticketTypeTrafficBtn = document.getElementById('ticket-type-traffic');

    function setTicketType(mode){
        // mode: 'ticket' or 'traffic'
        if(!ticketApp) return;
        if(mode === 'traffic'){
            document.getElementById('ticket-title').textContent = 'Traffic Ticket';
            document.querySelectorAll('.traffic-only').forEach(function(el){ el.style.display='flex'; });
            if(ticketTypeTrafficBtn) ticketTypeTrafficBtn.classList.add('active');
            if(ticketTypeTicketBtn) ticketTypeTicketBtn.classList.remove('active');
        } else {
            document.getElementById('ticket-title').textContent = 'Ticket';
            document.querySelectorAll('.traffic-only').forEach(function(el){ el.style.display='none'; });
            if(ticketTypeTicketBtn) ticketTypeTicketBtn.classList.add('active');
            if(ticketTypeTrafficBtn) ticketTypeTrafficBtn.classList.remove('active');
        }
    }

    if(ticketTypeTicketBtn) ticketTypeTicketBtn.addEventListener('click', function(){ setTicketType('ticket'); });
    if(ticketTypeTrafficBtn) ticketTypeTrafficBtn.addEventListener('click', function(){ setTicketType('traffic'); });

    function openTicket(data){
        // data.type: 'ticket' or 'traffic-ticket'
        if(data && data.type === 'traffic-ticket'){
            setTicketType('traffic');
        } else {
            setTicketType('ticket');
        }
        // Reset fields
        document.getElementById('ticket-date').value = new Date().toISOString().split('T')[0];
        var now = new Date();
        document.getElementById('ticket-time').value = now.toTimeString().slice(0,5);
        // Reset fields for both ticket types
        document.getElementById('ticket-receiver').value = data && data.receiver || '';
        // Traffic-specific vehicle info
        document.getElementById('traffic-license').value = data && data.plate || '';
        document.getElementById('traffic-make').value = data && data.make || '';
        document.getElementById('traffic-model').value = data && data.model || '';
        document.getElementById('traffic-vin').value = data && data.vin || '';
        // General fields
        document.getElementById('ticket-location').value = '';
        document.getElementById('ticket-violation').value = '';
        document.getElementById('ticket-amount').value = '';
        document.getElementById('ticket-due').value = '14';
        // Traffic-related fields
        document.getElementById('ticket-lictype').value = '';
        document.getElementById('ticket-revoke').value = 'no';
        document.getElementById('ticket-suspension').value = '';
        document.getElementById('ticket-points').value = '0';
        document.getElementById('ticket-points-count').value = '';
        // Comments
        document.getElementById('ticket-comment').value = '';
        ticketApp.classList.remove('hidden');
        // Start note-taking animation on the client
        var currentMode = document.getElementById('ticket-title').textContent.toLowerCase().includes('traffic') ? 'traffic-ticket' : 'ticket';
        post('startTicketAnimation',{ type: currentMode });
    }

    function closeTicket(){ ticketApp.classList.add('hidden'); post('closeTicket'); post('stopTicketAnimation'); }
    if(ticketClose) ticketClose.addEventListener('click', closeTicket);
    if(ticketSubmit) ticketSubmit.addEventListener('click', function(){
        // Gather ticket data
        var type = document.getElementById('ticket-title').textContent.toLowerCase().includes('traffic') ? 'traffic-ticket' : 'ticket';
        var data = {
            date: document.getElementById('ticket-date').value,
            time: document.getElementById('ticket-time').value,
            receiver: parseInt(document.getElementById('ticket-receiver').value) || 0,
            license: document.getElementById('traffic-license').value.trim(),
            make: document.getElementById('traffic-make').value.trim(),
            model: document.getElementById('traffic-model').value.trim(),
            vin: document.getElementById('traffic-vin').value.trim(),
            location: document.getElementById('ticket-location').value.trim(),
            violation: document.getElementById('ticket-violation').value.trim(),
            amount: parseInt(document.getElementById('ticket-amount').value) || 0,
            dueDays: parseInt(document.getElementById('ticket-due').value) || 0,
            licType: document.getElementById('ticket-lictype').value.trim(),
            revoke: document.getElementById('ticket-revoke').value,
            suspension: parseInt(document.getElementById('ticket-suspension').value) || 0,
            points: parseInt(document.getElementById('ticket-points').value) || 0,
            pointsCount: parseInt(document.getElementById('ticket-points-count').value) || 0,
            comment: document.getElementById('ticket-comment').value.trim()
        };
        // Basic validation depends on type
        if(type === 'traffic-ticket'){
            if(!data.receiver || !data.license || !data.make || !data.model || !data.vin || !data.violation || !data.amount){ showToast('Kérlek, tölts ki minden mezőt!','error'); return; }
        } else {
            if(!data.receiver || !data.violation || !data.amount){ showToast('Kérlek, tölts ki minden mezőt!','error'); return; }
        }
        // Send to server
        post('issueTicket',{ type:type, ticketData:data });
        showToast('Jegy kiállítása folyamatban...','inform');
        closeTicket();
    });

    function openTicketViewer(data){
        // data.ticket: details
        var body = document.getElementById('tv-body');
        body.innerHTML = '';
        if(!data || !data.ticket){ body.innerHTML = '<p>Nincs adat.</p>'; return; }
        var t = data.ticket;
        // Create rows for each field
        function addRow(label,value){
            var row=document.createElement('div'); row.className='ticket-row';
            var f1=document.createElement('div'); f1.className='ticket-field'; f1.style.flex='1'; f1.innerHTML='<label>'+label+'</label>'; var f2=document.createElement('div'); f2.className='ticket-field'; f2.style.flex='1'; f2.innerHTML='<span>'+esc(value)+'</span>'; row.appendChild(f1); row.appendChild(f2); body.appendChild(row);
        }
        // Compose display rows based on data fields
        addRow('Dátum', t.date + ' ' + t.time);
        if(t.receiver) addRow('Címzett', t.receiver);
        if(t.license) addRow('Rendszám', t.license);
        if(t.make) addRow('Márka', t.make);
        if(t.model) addRow('Modell', t.model);
        if(t.vin) addRow('VIN', t.vin);
        addRow('Helyszín', t.location);
        addRow('Sértés', t.violation);
        addRow('Bírság', fmt(t.amount) + ' Ft');
        addRow('Határidő', t.dueDays + ' nap');
        if(t.licType) addRow('Jogosítvány típusa', t.licType);
        if(t.revoke && t.revoke !== 'no') addRow('Visszavonás', t.revoke);
        if(t.suspension and t.suspension > 0) addRow('Felfüggesztés', t.suspension .. ' nap');
        if(t.points and t.points > 0) addRow('Büntetőpontok', t.points);
        if(t.pointsCount and t.pointsCount > 0) addRow('Pontok száma', t.pointsCount);
        if(t.comment) addRow('Megjegyzés', t.comment);
        ticketViewer.classList.remove('hidden');
    }
    function closeTicketViewer(){ ticketViewer.classList.add('hidden'); post('closeTicketViewer'); }
    if(tvClose) tvClose.addEventListener('click', closeTicketViewer);
    if(tvPayCash) tvPayCash.addEventListener('click', function(){ post('payTicket',{method:'cash'}); showToast('Készpénzes fizetés indítva','inform'); closeTicketViewer(); });
    if(tvPayBank) tvPayBank.addEventListener('click', function(){ post('payTicket',{method:'bank'}); showToast('Banki fizetés indítva','inform'); closeTicketViewer(); });

    function openInvoice(data){
        // Reset fields
        document.getElementById('inv-description').value = '';
        document.getElementById('inv-quantity').value = '1';
        document.getElementById('inv-unit').value = '';
        document.getElementById('inv-tax').value = '0';
        document.getElementById('inv-buyer').value = '';
        invoiceSignature.classList.remove('signed');
        invoiceSignature.innerHTML = '<span>Kattints az aláíráshoz</span>';
        invoiceApp.classList.remove('hidden');
    }
    function closeInvoice(){ invoiceApp.classList.add('hidden'); post('closeInvoice'); post('stopSigning'); }
    if(invoiceClose) invoiceClose.addEventListener('click', closeInvoice);
    if(invoiceSubmit) invoiceSubmit.addEventListener('click', function(){
        var desc = document.getElementById('inv-description').value.trim();
        var qty = parseInt(document.getElementById('inv-quantity').value) || 1;
        var unit = parseInt(document.getElementById('inv-unit').value) || 0;
        var tax = parseInt(document.getElementById('inv-tax').value) || 0;
        var buyer = parseInt(document.getElementById('inv-buyer').value) || 0;
        if(!desc || !unit || !buyer){ showToast('Kérlek, tölts ki minden mezőt!','error'); return; }
        // Create invoice data
        var data = { description:desc, quantity:qty, unitPrice:unit, taxPercent:tax, buyer:buyer };
        post('issueInvoice', data);
        showToast('Számla kiállítása folyamatban...','inform');
        closeInvoice();
    });
    if(invoiceSignature) invoiceSignature.addEventListener('click', function(){
        if(invoiceSignature.classList.contains('signed')) return;
        // Notify client to start signing animation
        post('startSigning');
        invoiceSignature.classList.add('signed');
        invoiceSignature.innerHTML = '<span>Aláírva</span>';
    });
    function openInvoiceViewer(data){
        var body = document.getElementById('iv-body'); body.innerHTML='';
        if(!data || !data.invoice){ body.innerHTML = '<p>Nincs adat.</p>'; return; }
        var inv = data.invoice;
        // build invoice summary
        function addInvRow(label,value){
            var row=document.createElement('div'); row.className='invoice-row';
            var f1=document.createElement('div'); f1.className='invoice-field'; f1.style.flex='1'; f1.innerHTML='<label>'+label+'</label>'; var f2=document.createElement('div'); f2.className='invoice-field'; f2.style.flex='1'; f2.innerHTML='<span>'+esc(value)+'</span>'; row.appendChild(f1); row.appendChild(f2); body.appendChild(row);
        }
        addInvRow('Leírás', inv.description);
        addInvRow('Mennyiség', inv.quantity);
        addInvRow('Egységár', fmt(inv.unitPrice) + ' Ft');
        addInvRow('Adó', inv.taxPercent + '%');
        addInvRow('Összesen', fmt(inv.total) + ' Ft');
        invoiceViewer.classList.remove('hidden');
    }
    function closeInvoiceViewer(){ invoiceViewer.classList.add('hidden'); post('closeInvoiceViewer'); }
    if(ivClose) ivClose.addEventListener('click', closeInvoiceViewer);
    if(ivAccept) ivAccept.addEventListener('click', function(){ post('payInvoice',{method:'accept'}); showToast('Számla elfogadva','success'); closeInvoiceViewer(); });
    if(ivReject) ivReject.addEventListener('click', function(){ post('payInvoice',{method:'reject'}); showToast('Számla elutasítva','error'); closeInvoiceViewer(); });


    // ═══ ESCAPE ═══
    document.addEventListener('keydown', function(e){
        if(e.key==='Escape'){
            if(!cityhallApp.classList.contains('hidden')) closeCityHall();
            else if(!receiptViewer.classList.contains('hidden')) closeReceipt();
            else if(!terminalApp.classList.contains('hidden')) closeTerminal();
        }
    });

    // ═══ HELPERS ═══
    function post(name, data){ fetch('https://realrpg_cityhall/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data||{})}).catch(function(){}); }
    function fmt(n){ return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g,' '); }
    function esc(t){ if(!t) return ''; var d=document.createElement('div'); d.appendChild(document.createTextNode(t)); return d.innerHTML; }
    function showToast(msg,type){
        type=type||'inform';
        var t=document.createElement('div'); t.className='toast '+type;
        var icon='fa-info-circle'; if(type==='success') icon='fa-check-circle'; else if(type==='error') icon='fa-exclamation-circle';
        t.innerHTML='<i class="fas '+icon+'"></i><span>'+esc(msg)+'</span>';
        toastContainer.appendChild(t);
        setTimeout(function(){ t.style.animation='toastOut .3s ease forwards'; setTimeout(function(){ if(t.parentNode) t.parentNode.removeChild(t); },300); },4000);
    }
})();
