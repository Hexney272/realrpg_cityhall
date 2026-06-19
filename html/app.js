// This script is intentionally left mostly empty.  The city hall menus
// leverage ox_lib for their UI.  If you wish to build a more complex
// front‑end for your city hall, initialise it here.  The file is loaded
// automatically when the NUI page is invoked.
window.addEventListener('message', (event) => {
    const data = event.data;
    // Here you could react to events sent from the Lua side if building a
    // custom interface.  For now we simply log them.
    console.log('Received message from Lua:', data);
});