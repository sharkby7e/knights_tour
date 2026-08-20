const coord = sq => `${(sq.x - 0.5) * 12.5},${(8 - sq.y + 0.5) * 12.5}`

export function pathPoints(squares) {
  return squares.map(coord).join(" ")
}

export function renderPath(svgEl, squares) {
  if (squares.length < 2) {
    svgEl.innerHTML = ""
    return
  }

  const startDot = `<circle cx="${(squares[0].x - 0.5) * 12.5}" cy="${(8 - squares[0].y + 0.5) * 12.5}" r="2.25" class="fill-board-legal" />`
  const coords = pathPoints(squares)
  svgEl.innerHTML = `
    <polyline points="${coords}" fill="none" stroke="#3df3ff" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke" />
    <polyline points="${coords}" fill="none" stroke="#ff2ee0" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke" class="animate-pulse-line" />
    ${startDot}
  `
}
