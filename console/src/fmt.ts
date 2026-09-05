// Local time, 24-hour, ISO order. The current page prints UTC and labels
// nothing, and seeds its datetime-local input with a UTC string, so the
// default end-date shown is off by the timezone. Both fixed here.
function two(n: number): string {
  return String(n).padStart(2, '0')
}

export function localDateTime(d: Date): string {
  return `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())} ${two(d.getHours())}:${two(d.getMinutes())}`
}

// What an <input type="datetime-local"> wants as its value.
export function inputDateTime(d: Date): string {
  return `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())}T${two(d.getHours())}:${two(d.getMinutes())}`
}
