async function getAudioEffects({ blob, detectionThreshold, maxAmp = 1.0 } ) {
  const audioContext = new (window.AudioContext || window.webkitAudioContext)();
  const arrayBuffer = await blob.arrayBuffer();
  const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);
  const channelData = audioBuffer.getChannelData(0); // Get the data for the first channel

  let offset = 0;
  let maxVolume = 0;

  for (let i = 0; i < channelData.length; i++) {
    const amplitude = Math.abs(channelData[i]);
    if (amplitude > detectionThreshold && offset == 0) {
      offset = i / audioBuffer.sampleRate;
    }

    if (amplitude > maxVolume) {
      maxVolume = amplitude
    }
  }

  return { offset, amplifier: maxAmp / maxVolume }
}



export const audioHandler = () => {
  const audioContext = new (window.AudioContext || window.webkitAudioContext)();
  const buffers = {};

  // Decode audio file into a data buffer
  const decodeBlob = (blob) => {
    return new Promise((res, rej) => {
      const reader = new FileReader();

      reader.onload = function(event) {
        const arrayBuffer = event.target.result;

        audioContext.decodeAudioData(arrayBuffer)
          .then(audioBuffer => res(audioBuffer))
          .catch(error => {
            console.error('Error decoding audio data:', error);
          });
      };

      reader.readAsArrayBuffer(blob);
    })
  }
  const base64ToBlob = (base64) => {
    const byteCharacters = atob(base64); // Decode Base64 string
    const byteNumbers = new Array(byteCharacters.length);

    for (let i = 0; i < byteCharacters.length; i++) {
      byteNumbers[i] = byteCharacters.charCodeAt(i); // Convert each character to its char code
    }

    const byteArray = new Uint8Array(byteNumbers); // Create a Uint8Array from char codes
    return new Blob([byteArray]); // Create and return a Blob
  }

  const loadAudios = (audios) => {
    return Promise.all(
      audios.map(({ id, data, offset = 0 }) => {
        const blob = base64ToBlob(data);
        return (
          decodeBlob(blob)
            .then((buffer) => { buffers[id] = { buffer, offset } })
        )
      })
    )
  }

  // audios: { id, volume, offset }
  let startTime;
  let cutoffs = {};
  const playSounds = ({ sounds, resetOffset }) => {
    if (resetOffset || !startTime) {
      startTime = audioContext.currentTime
    }
    sounds.forEach(({ id, volume, offset, cutoff }) => {
      const source = audioContext.createBufferSource();
      source.buffer = buffers[id].buffer

      // set volume

      const gainNode = audioContext.createGain()
      gainNode.gain.value = volume
      gainNode.connect(audioContext.destination)
      if (volume > 0) {
        source.connect(gainNode)
        cutoffs[id]?.stop(startTime + offset)
        if (cutoff) { cutoffs[id] = source }
        source.start(startTime + offset, buffers[id].offset)
      }
    })
  }

  const requestMic = () => {
    return (
      navigator
        .mediaDevices
        .getUserMedia({ audio: true })
    )
  }

  let mediaRecorder;
  let chunks = [];
  const startRecording = () => {
    return (
      navigator
        .mediaDevices
        .getUserMedia({ audio: true })
        .then((stream) => {

          mediaRecorder = new MediaRecorder(stream)

          mediaRecorder.ondataavailable = function (e) {
            chunks.push(e.data);
          };
          mediaRecorder.start()
        })
    )
  }

  function blobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => {
        const base64data = reader.result.split(',')[1]; // Get the Base64 part
        resolve(base64data);
      };
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  }

  // function base64ToBlob(base64, type = 'audio/wav') {
  //   const byteCharacters = atob(base64); // Decode Base64 string
  //   const byteNumbers = new Array(byteCharacters.length);

  //   for (let i = 0; i < byteCharacters.length; i++) {
  //     byteNumbers[i] = byteCharacters.charCodeAt(i); // Convert each character to its char code
  //   }

  //   const byteArray = new Uint8Array(byteNumbers); // Create a Uint8Array from char codes
  //   return new Blob([byteArray], { type }); // Create and return a Blob
  // }

  function playAudioFromBase64(base64Audio) {
    const audioBlob = base64ToBlob(base64Audio); // Convert Base64 to Blob
    const audioUrl = URL.createObjectURL(audioBlob); // Create an object URL for the audio Blob

    const audio = new Audio(audioUrl); // Create a new Audio object
    audio.play() // Play the audio
      .then(() => {
          console.log('Audio is playing');
      })
      .catch((error) => {
          console.error('Error playing audio:', error);
      });
  }

  const stopRecording = (id) => {
    return new Promise((res, rej) => {

      mediaRecorder.onstop = (e) => {
        const blob = new Blob(chunks, { type: mediaRecorder.mimeType });

        chunks = []
        blobToBase64(blob).then(text => {
          getAudioEffects({ blob, detectionThreshold: 0.01 })
            .then(({ offset, amplifier }) => {
              loadAudios([{ id, data: text, offset }])
                .then(() => { res({ data: text, offset, amplifier }) })
            })
        })
      }

      mediaRecorder.stop()
    })
  }

  return ({ payload, dispatch }) => {
    const event = payload?.streams?.default;

    if (!event) { return }

    if (event.type == "load") {
      loadAudios(event.payload)
        .then(() => { dispatch({ type: "loaded", payload: { id: event.id } }) })
    } else if (event.type == "play") {
      playSounds(event.payload)
    } else if (event.type == "request-mic") {
      requestMic().then(() => dispatch({ id: event.id, type: "mic-ready", payload: { id: event.id } }))
    } else if (event.type == "start-record") {
      startRecording().then(() => dispatch({ type: "recording-started", payload: { id: event.id } }))
    } else if (event.type == "stop-record") {
      stopRecording(event.id).then(({ data, offset, amplifier }) => {
        dispatch({
          id: event.id,
          type: "recording-stopped",
          payload: {
            id: event.id,
            data,
            offset,
            amplifier,
          }
        })
      })
    }
  }
}
