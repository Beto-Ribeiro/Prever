/**
 * Utilitários puros de validação, sanitização e cálculo geoespacial compartilhados no monorepo PREVER.
 */

export function onlyDigits(value) {
  return String(value ?? '').replace(/\D+/g, '')
}

export function isValidEmail(email) {
  const normalized = String(email ?? '').trim().toLowerCase()
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)
}

export function isValidCoordinate(lat, lng) {
  return (
    typeof lat === 'number' &&
    typeof lng === 'number' &&
    Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    !(lat === 0 && lng === 0)
  )
}

export function matchesSosCpfConfirmation(storedCpf, typedInput) {
  const cpfDigits = onlyDigits(storedCpf)
  const typedDigits = onlyDigits(typedInput)
  if (cpfDigits.length < 3) return false
  return (
    (typedDigits.length === 3 && cpfDigits.startsWith(typedDigits)) ||
    (typedDigits.length === 11 && cpfDigits === typedDigits)
  )
}

export function calculateHaversineDistanceKm(lat1, lon1, lat2, lon2) {
  if (!isValidCoordinate(lat1, lon1) || !isValidCoordinate(lat2, lon2)) {
    return null
  }
  const toRad = (deg) => (deg * Math.PI) / 180
  const earthRadiusKm = 6371
  const dLat = toRad(lat2 - lat1)
  const dLon = toRad(lon2 - lon1)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return earthRadiusKm * c
}
