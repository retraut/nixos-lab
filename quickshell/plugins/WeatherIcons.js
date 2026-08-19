.pragma library

// One Open-Meteo -> Nerd Font mapping shared by the bar summary and the
// weather panel. Keeping this in one module prevents rain/snow/storm states
// from drifting between the two UIs.
function icon(code, isDay) {
  var c = Number(code)
  if (c === 0) return Number(isDay) === 0 ? "" : ""
  if (c === 1 || c === 2) return Number(isDay) === 0 ? "" : ""
  if (c === 3 || c === 45 || c === 48) return ""
  if (c >= 71 && c <= 77) return ""
  if (c >= 51 && c <= 82) return ""
  if (c >= 95) return ""
  return ""
}
