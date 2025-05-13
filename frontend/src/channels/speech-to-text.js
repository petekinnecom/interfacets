let activeRecognition = null;
let inactivityTimer = null;

const INACTIVITY_TIMEOUT_MS = 3000;

const captureSpeech = async (onProgress, onSubmit) => {
  // Use Web Speech API
  return new Promise((resolve, reject) => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      reject(new Error("SpeechRecognition API not supported"));
      return;
    }
    const recognition = new SpeechRecognition();
    recognition.lang = 'en-US';
    recognition.interimResults = true;
    recognition.maxAlternatives = 1;
    recognition.continuous = true;

    let finalTranscript = "";
    let lastFinalLength = 0; // Track processed transcript length

    recognition.onresult = (event) => {
      let interimTranscript = "";
      let newFinal = "";
      for (let i = event.resultIndex; i < event.results.length; ++i) {
        const transcript = event.results[i][0].transcript;
        if (event.results[i].isFinal) {
          newFinal += transcript;
        } else {
          interimTranscript += transcript;
        }
      }
      // Only append new part of the final transcript
      if (newFinal.length > 0) {
        // Remove already processed part if Chrome mobile repeats
        if (finalTranscript && newFinal.startsWith(finalTranscript)) {
          finalTranscript = newFinal;
        } else {
          finalTranscript += newFinal;
        }
      }
      if (onProgress) {
        onProgress(finalTranscript + interimTranscript);
      }
      // Reset inactivity timer on every result
      if (onSubmit) {
        if (inactivityTimer) clearTimeout(inactivityTimer);
        inactivityTimer = setTimeout(() => {
          onSubmit(finalTranscript + interimTranscript);
          finalTranscript = ""; // Reset transcript after submit
        }, INACTIVITY_TIMEOUT_MS);
      }
      // Do not resolve here; keep listening endlessly
    };

    recognition.onerror = (event) => {
      // On network or not-allowed errors, stop and reject
      if (event.error === "not-allowed" || event.error === "network") {
        recognition.stop();
        reject(event.error);
      }
      // Otherwise, try to restart on other errors
    };

    recognition.onend = () => {
      // Restart recognition to keep listening endlessly
      if (activeRecognition === recognition) {
        recognition.start();
      }
    };

    recognition.onnomatch = () => {
      // No speech recognized, but keep listening
    };

    activeRecognition = recognition;
    recognition.start();
    // Never resolve, keeps listening endlessly
  });
}

export const speechToTextHandler = () => {
  return ({ payload, dispatch }) => {
    const event = payload?.streams?.default;
    if (!event) { return }

    if (event.type == "record") {
      captureSpeech(
        (progressText) => {
          dispatch({
            id: event.id,
            type: "text-progress",
            payload: {
              id: event.id,
              text: progressText
            }
          });
        },
        (submitText) => {
          dispatch({
            id: event.id,
            type: "text-submit",
            payload: {
              id: event.id,
              text: submitText
            }
          });
        }
      ).then((text) => {
        dispatch({
          id: event.id,
          type: "text-result",
          payload: {
            id: event.id,
            text
          }
        })
      })
    }

    if (event.type == "stop") {
      if (activeRecognition) {
        activeRecognition.onend = null;
        activeRecognition.stop();
        activeRecognition = null;
      }
      if (inactivityTimer) {
        clearTimeout(inactivityTimer);
        inactivityTimer = null;
      }
    }
  }
}
