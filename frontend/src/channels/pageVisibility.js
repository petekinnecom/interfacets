export const pageVisibilityHandler = (document) => {
  let myDispatch = () => { }

  document.addEventListener('visibilitychange', () => {
    myDispatch({ payload: { state: document.visibilityState } })
  });

  return ({ dispatch }) => { myDispatch = dispatch }
}
