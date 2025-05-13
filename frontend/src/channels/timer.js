export const timerHandler = () => {
  return ({ payload, dispatch }) => {
    const event = payload?.streams?.default;
    if (!event.ms) { return }

    setTimeout(
      () => { dispatch({ payload: event.response }) },
      event.ms
    )
  }
}
