export const submitHandler = (apiFetch) => {
  if (!apiFetch) {
    apiFetch = ({ url, method, body }) => {
      const authenticityToken = (
        document.querySelector("meta[name='csrf-token']")?.content
      )

      return fetch(
        url || window.location.href,
        {
          method: method,
          body: JSON.stringify(body),
          headers: {
            "X-CSRF-Token": authenticityToken,
            "Content-Type": "application/json",
            "Accept": "application/json",
          }
        }
      ).then(r => r.json())
    }
  }

  return ({ payload, dispatch }) => {
    const apiPayload = payload?.streams?.default
    if (!apiPayload) { return }

    return (
      apiFetch(apiPayload)
        .then((json) => dispatch(json))
        .catch((error) => {
          console.error(error)
          alert('failed to save')
        })
    )
  }
}
