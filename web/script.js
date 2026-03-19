let currentProxyUrl = "";
let hlsPlayer = null;

/**
 * Generates a proxy URL based on the current window location
 */
function generateOnly() {
    const sourceInput = document.getElementById('sourceUrl').value.trim();
    if (!sourceInput) {
        alert("Please enter a valid source URL!");
        return;
    }

    // Creating a clean proxy link by removing the protocol from source
    const cleanUrl = sourceInput.replace(/^https?:\/\//, '');
    currentProxyUrl = `${window.location.origin}/live/${cleanUrl}`;

    document.getElementById('result').innerText = currentProxyUrl;
}

/**
 * Initializes and plays the video stream
 * @param {string} type - 'source' or 'proxy'
 */
function playUrl(type) {
    let targetUrl = "";

    if (type === 'source') {
        targetUrl = document.getElementById('sourceUrl').value.trim();
    } else {
        if (!currentProxyUrl) generateOnly();
        targetUrl = currentProxyUrl;
    }

    if (!targetUrl || targetUrl.includes("...")) return;

    // Reveal player and update info
    const playerSection = document.getElementById('playerSection');
    const playingNow = document.getElementById('playingNow');
    const video = document.getElementById('video');

    playerSection.style.display = 'block';
    playingNow.innerText = `Streaming: ${targetUrl}`;

    // Clean up previous instance
    if (hlsPlayer) {
        hlsPlayer.destroy();
    }

    // HLS.js logic
    if (Hls.isSupported()) {
        hlsPlayer = new Hls();
        hlsPlayer.loadSource(targetUrl);
        hlsPlayer.attachMedia(video);
        hlsPlayer.on(Hls.Events.MANIFEST_PARSED, () => video.play());
    }
    // Native HLS support (Safari)
    else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = targetUrl;
        video.addEventListener('loadedmetadata', () => video.play());
    }
}

/**
 * Copies the generated link to clipboard
 */
function copyResult() {
    const text = document.getElementById('result').innerText;
    if (!text || text.includes("...")) return;

    navigator.clipboard.writeText(text).then(() => {
        const toast = document.getElementById('toast');
        toast.style.display = 'block';
        setTimeout(() => { toast.style.display = 'none'; }, 2500);
    });
}