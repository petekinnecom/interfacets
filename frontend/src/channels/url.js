export const toQueryParam = (hash) => {
  return Object.keys(hash)
    .map(key => {
      const value = hash[key];
      if (Array.isArray(value)) {
        return value.map(v => `${encodeURIComponent(key)}[]=${encodeURIComponent(v)}`).join('&');
      } else {
        return `${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
      }
    })
    .join('&');
};

function isPresent(obj) {

  return obj && Object.keys(obj).length > 0;
}

export const urlHandler = () => {
  // FOR NOW!
  window.addEventListener("popstate", function(e){
    window.location.reload();
  });

  return ({ payload, dispatch }) => {
    const urlSpec = payload.streams?.default?.urlSpec

    if (urlSpec) {
      const { url, queryParams } = urlSpec
      const fullUrl = url + (isPresent(queryParams) ? `?${toQueryParam(queryParams)}` : '')
      if (window.location != fullUrl) {
        history.pushState({ fullUrl }, "", fullUrl)
      }
    }

    const redirectSpec = payload.streams?.default?.redirectUrlSpec

    if (redirectSpec) {
      const { url, queryParams } = redirectSpec
      const fullUrl = url + (isPresent(queryParams) ? `?${toQueryParam(queryParams)}` : '')

      if (window.location.href != fullUrl) {
        window.location = fullUrl
      }
    }
  }
}
