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

    window.addEventListener('message', function (event) {
        var data = event.data;
        switch (data.action) {
            case 'openCityHall': openCityHall(data); break;
            case 'openReceipt': openReceipt(data); break;
            case 'openTerminal': openTerminal(); break;
            case 'vinResult': showVINResult(data.info); break;
            case 'notify': showToast(data.message, data.type); break;
            case 'printDone': onPrintDone(); break;
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
