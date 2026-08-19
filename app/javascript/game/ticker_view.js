export function tickerView(notations, currentIndex) {
  return notations.map((notation, i) => ({ notation, current: i === currentIndex }))
}
