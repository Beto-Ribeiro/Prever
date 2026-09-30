import { useEffect, useRef, useState, forwardRef, useImperativeHandle, useCallback } from 'react'
import { Map, AdvancedMarker, InfoWindow, useMap } from '@vis.gl/react-google-maps'
import { Map3D, Marker3D, Popover, CirclePath, useMap3D } from '@vis.gl/react-google-maps/3d'

const SEVERITY_STYLE = {
  Crítico: { color: '#c60202', radius: 3000, opacity: 0.24, shape: 'critical', label: 'Crítico' },
  Grave: { color: '#ff6a00', radius: 2300, opacity: 0.2, shape: 'severe', label: 'Grave' },
  Moderado: { color: '#cab900', radius: 1700, opacity: 0.18, shape: 'regular', label: 'Moderado' },
}

function getSeverityStyle(severidade, colorBlind = false) {
  const base = SEVERITY_STYLE[severidade] || SEVERITY_STYLE.Moderado
  if (!colorBlind) return base
  const safeColors = { critical: '#005cab', severe: '#d95f02', regular: '#7570b3' }
  return { ...base, color: safeColors[base.shape] || base.color }
}

function getShelterMeta(status) {
  if (status === 'lotado') return { label: 'Lotado', color: '#c60202', text: '#ffffff' }
  if (status === 'quase_lotado') return { label: 'Quase lotado', color: '#ff6a00', text: '#111827' }
  if (status === 'inativo') return { label: 'Inativo', color: '#64748b', text: '#ffffff' }
  return { label: 'Disponível', color: '#00c000', text: '#052e12' }
}

function isValidCoord(value) {
  return typeof value === 'number' && Number.isFinite(value)
}

function OccurrenceMarker({ item, colorBlind, onOccurrenceDetails, is3D }) {
  const [open, setOpen] = useState(false)
  const style = getSeverityStyle(item.severidade, colorBlind)
  
  const glyph = style.shape === 'critical'
    ? `<span aria-hidden="true" style="display:block;width:24px;height:24px;background:${style.color};border:4px double #fff;box-shadow:0 0 0 2px rgba(15,23,42,.35);transform:rotate(45deg);"></span>`
    : style.shape === 'severe'
      ? `<span aria-hidden="true" style="display:block;width:0;height:0;border-left:14px solid transparent;border-right:14px solid transparent;border-bottom:26px solid ${style.color};filter:drop-shadow(0 0 1px #fff) drop-shadow(0 2px 3px rgba(15,23,42,.38));"></span>`
      : `<span aria-hidden="true" style="display:block;width:23px;height:23px;border-radius:999px;background:${style.color};border:3px solid #fff;box-shadow:0 0 0 2px rgba(15,23,42,.35);"></span>`

  const markerContent = (
    <span title={style.label} style={{ position: 'relative', display: 'inline-flex', width: 34, height: 34, alignItems: 'center', justifyContent: 'center', filter: 'drop-shadow(0 3px 6px rgba(15,23,42,.45))' }} dangerouslySetInnerHTML={{ __html: glyph }} />
  )

  const popupContent = (
    <div className="smdn-map-popup text-slate-800 p-2 min-w-[200px]">
      <strong className="block mb-1">{item.titulo || 'Ocorrência'}</strong>
      <div className="mb-2">Severidade: {item.severidade || 'Moderado'}</div>
      {onOccurrenceDetails && (
        <button type="button" className="text-blue-600 underline font-bold" onClick={(e) => { e.preventDefault(); onOccurrenceDetails(item); }}>
          Ver detalhes
        </button>
      )}
    </div>
  )

  if (is3D) {
    return (
      <>
        <Marker3D position={{ lat: item.lat, lng: item.lng }} onClick={() => setOpen(true)}>{markerContent}</Marker3D>
        {open && <Popover position={{ lat: item.lat, lng: item.lng }} onClose={() => setOpen(false)}>{popupContent}</Popover>}
      </>
    )
  }
  return (
    <>
      <AdvancedMarker position={{ lat: item.lat, lng: item.lng }} onClick={() => setOpen(true)}>{markerContent}</AdvancedMarker>
      {open && <InfoWindow position={{ lat: item.lat, lng: item.lng }} onCloseClick={() => setOpen(false)}>{popupContent}</InfoWindow>}
    </>
  )
}

function ShelterMarker({ item, isSelected, onShelterSelect, is3D }) {
  const [open, setOpen] = useState(isSelected)
  const meta = getShelterMeta(item.status)
  
  const markerContent = (
    <span style={{
      display: 'inline-flex', width: 34, height: 34, alignItems: 'center', justifyContent: 'center', borderRadius: 12,
      background: meta.color, color: meta.text, border: '2px solid #fff',
      boxShadow: isSelected ? '0 0 0 3px rgba(255,255,255,.96), 0 0 0 7px rgba(14,165,233,.48)' : '0 0 0 2px rgba(15,23,42,.25), 0 5px 12px rgba(15,23,42,.38)',
      transform: isSelected ? 'scale(1.18)' : 'none',
      transition: 'all 0.2s'
    }} onClick={() => { setOpen(true); onShelterSelect?.(item); }}>
      <svg viewBox="0 0 24 24" style={{ width: 21, height: 21, fill: 'none', stroke: 'currentColor', strokeWidth: 2.2, strokeLinecap: 'round', strokeLinejoin: 'round' }}>
        <path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 10.5V20h13v-9.5"/><path d="M9.5 20v-6h5v6"/>
      </svg>
    </span>
  )

  const popupContent = (
    <div className="smdn-map-popup text-slate-800 p-2 min-w-[200px]">
      <strong className="block mb-1">{item.name || 'Abrigo'}</strong>
      <div className="text-sm">{[item.city, item.location].filter(Boolean).join(' · ') || 'Local não informado'}</div>
      <div className="text-sm mt-1"><b>Lotação:</b> {Number(item.occupied || 0)}/{Number(item.capacity || 0)}</div>
      <div className="text-sm"><b>Status:</b> {meta.label}</div>
    </div>
  )

  if (is3D) {
    return (
      <>
        <Marker3D position={{ lat: item.lat, lng: item.lng }} zIndex={isSelected ? 100 : 1}>{markerContent}</Marker3D>
        {open && <Popover position={{ lat: item.lat, lng: item.lng }} onClose={() => setOpen(false)}>{popupContent}</Popover>}
      </>
    )
  }
  return (
    <>
      <AdvancedMarker position={{ lat: item.lat, lng: item.lng }} zIndex={isSelected ? 100 : 1}>{markerContent}</AdvancedMarker>
      {open && <InfoWindow position={{ lat: item.lat, lng: item.lng }} onCloseClick={() => setOpen(false)}>{popupContent}</InfoWindow>}
    </>
  )
}

function VictimMarker({ item, onVictimAssistance, savingVictimId, is3D }) {
  const [open, setOpen] = useState(false)
  const attended = item.assistanceStatus === 'atendida'
  
  const markerContent = (
    <span style={{
      position: 'relative', display: 'inline-flex', width: 28, height: 28, alignItems: 'center', justifyContent: 'center',
      borderRadius: 999, background: attended ? '#0f766e' : '#020617', border: '2px solid #fff',
      boxShadow: '0 0 0 2px rgba(15, 23, 42, 0.2), 0 3px 8px rgba(15, 23, 42, 0.45)'
    }}>
      <span style={{ position: 'absolute', top: 6, width: 7, height: 7, borderRadius: 999, background: '#fff' }}></span>
      <span style={{ position: 'absolute', bottom: 6, width: 12, height: 8, borderRadius: '999px 999px 3px 3px', background: '#fff' }}></span>
    </span>
  )

  const popupContent = (
    <div className="smdn-map-popup text-slate-800 p-2 min-w-[220px]">
      <strong className="block mb-1">{item.name || 'Vítima localizada'}</strong>
      <div className="text-sm mb-1">{item.source === 'localizacao_dispositivo' ? 'Localização do dispositivo' : 'Último relato com localização'}</div>
      <div className="text-sm mb-2">
        <b>Status:</b> <span style={{ color: attended ? '#16a34a' : '#b45309', fontWeight: 600 }}>{attended ? 'Atendida / socorrida' : 'Pendente de atendimento'}</span>
      </div>
      {!attended && onVictimAssistance && (
        <button type="button" disabled={savingVictimId === item.id} className="text-blue-600 underline font-bold disabled:opacity-50" onClick={() => onVictimAssistance(item)}>
          {savingVictimId === item.id ? 'Salvando...' : 'Marcar como atendida'}
        </button>
      )}
    </div>
  )

  if (is3D) {
    return (
      <>
        <Marker3D position={{ lat: item.lat, lng: item.lng }} onClick={() => setOpen(true)}>{markerContent}</Marker3D>
        {open && <Popover position={{ lat: item.lat, lng: item.lng }} onClose={() => setOpen(false)}>{popupContent}</Popover>}
      </>
    )
  }
  return (
    <>
      <AdvancedMarker position={{ lat: item.lat, lng: item.lng }} onClick={() => setOpen(true)}>{markerContent}</AdvancedMarker>
      {open && <InfoWindow position={{ lat: item.lat, lng: item.lng }} onCloseClick={() => setOpen(false)}>{popupContent}</InfoWindow>}
    </>
  )
}

function CircleOutline({ center, radius, is3D }) {
  if (is3D) {
    return <CirclePath center={center} radius={radius} strokeColor="#44769b" strokeWidth={2} fillColor="#44769b" fillOpacity={0.12} />
  }
  // Circle rendering on 2D map requires a hook or child component with useMap. 
  // Let's implement it inside the map using standard AdvancedMarker for simplicity, or omit since AdvancedMarker is large.
  return null;
}

const MapView = forwardRef(function MapView(
  { ocorrencias = [], vitimas = [], abrigos = [], onMapClick, onOccurrenceDetails, onVictimAssistance, onShelterSelect, savingVictimId, selectedShelterId, targetLocation, heatmap = false, mapMode, colorBlind = false, selectionRadiusKm = 3, showSelectionRadius = true },
  ref
) {
  const [is3D, setIs3D] = useState(false)
  const effectiveMode = mapMode || (heatmap ? 'heat' : 'points')
  const showOccurrences = effectiveMode !== 'victims'
  const [center, setCenter] = useState({ lat: -23.5505, lng: -46.6333 })
  const [zoom, setZoom] = useState(10)

  const validOccurrences = ocorrencias.filter((item) => isValidCoord(item.lat) && isValidCoord(item.lng))
  const validVictims = vitimas.filter((item) => isValidCoord(item.lat) && isValidCoord(item.lng))
  const validShelters = abrigos.filter((item) => isValidCoord(item.lat) && isValidCoord(item.lng))

  useImperativeHandle(ref, () => ({
    flyTo(lat, lng, newZoom = 15) {
      setCenter({ lat, lng })
      setZoom(newZoom)
    }
  }))

  useEffect(() => {
    if (!targetLocation) return
    if (isValidCoord(targetLocation.lat) && isValidCoord(targetLocation.lon)) {
      setCenter({ lat: targetLocation.lat, lng: targetLocation.lon })
      setZoom(targetLocation.neighborhood ? 14 : 12)
      return
    }
    const query = [targetLocation.neighborhood, targetLocation.city].filter(Boolean).join(', ')
    if (!query) return
    fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=1`)
      .then((r) => r.json())
      .then((results) => {
        if (!results.length) return
        setCenter({ lat: parseFloat(results[0].lat), lng: parseFloat(results[0].lon) })
        setZoom(targetLocation.neighborhood ? 14 : 12)
      }).catch(() => {})
  }, [targetLocation])

  const renderMarkers = (is3dMode) => (
    <>
      {showOccurrences && validOccurrences.map(o => <OccurrenceMarker key={o.id} item={o} colorBlind={colorBlind} onOccurrenceDetails={onOccurrenceDetails} is3D={is3dMode} />)}
      {validVictims.map(v => <VictimMarker key={v.id} item={v} onVictimAssistance={onVictimAssistance} savingVictimId={savingVictimId} is3D={is3dMode} />)}
      {validShelters.map(s => <ShelterMarker key={s.id} item={s} isSelected={s.id === selectedShelterId} onShelterSelect={onShelterSelect} is3D={is3dMode} />)}
      
      {targetLocation && isValidCoord(targetLocation.lat) && (
        <>
          {showSelectionRadius && <CircleOutline center={{ lat: targetLocation.lat, lng: targetLocation.lon }} radius={Math.max(0.5, Number(selectionRadiusKm) || 3) * 1000} is3D={is3dMode} />}
          {is3dMode ? (
            <Marker3D position={{ lat: targetLocation.lat, lng: targetLocation.lon }}>
              <div style={{ width: 20, height: 20, background: '#44769b', border: '3px solid white', borderRadius: '50%' }} />
            </Marker3D>
          ) : (
            <AdvancedMarker position={{ lat: targetLocation.lat, lng: targetLocation.lon }}>
              <div style={{ width: 20, height: 20, background: '#44769b', border: '3px solid white', borderRadius: '50%' }} />
            </AdvancedMarker>
          )}
        </>
      )}
    </>
  )

  return (
    <div className="relative w-full h-full smdn-map-root">
      <div className="absolute top-4 left-4 z-50 flex gap-2">
        <button type="button" onClick={() => setIs3D(false)} className={`px-4 py-2 rounded-lg font-semibold text-sm shadow-md transition-colors ${!is3D ? 'bg-blue-600 text-white' : 'bg-white text-slate-700 hover:bg-slate-50'}`}>
          Mapa 2D
        </button>
        <button type="button" onClick={() => setIs3D(true)} className={`px-4 py-2 rounded-lg font-semibold text-sm shadow-md transition-colors ${is3D ? 'bg-blue-600 text-white' : 'bg-white text-slate-700 hover:bg-slate-50'}`}>
          Satélite 3D (Photorealistic)
        </button>
      </div>

      {is3D ? (
        <Map3D 
          center={{ lat: center.lat, lng: center.lng, altitude: zoom < 14 ? 15000 : 2000 }} 
          tilt={60} 
          heading={0}
          onClick={(e) => {
            if (e.detail?.position && onMapClick) {
              onMapClick(e.detail.position.lat, e.detail.position.lng)
            }
          }}
        >
          {renderMarkers(true)}
        </Map3D>
      ) : (
        <Map 
          defaultZoom={zoom} 
          defaultCenter={center} 
          center={center}
          zoom={zoom}
          onCameraChanged={(e) => { setCenter(e.detail.center); setZoom(e.detail.zoom); }}
          onClick={(e) => {
            if (e.detail?.latLng && onMapClick) {
              onMapClick(e.detail.latLng.lat, e.detail.latLng.lng)
            }
          }}
          mapId="DEMO_MAP_ID" 
          gestureHandling="greedy"
          disableDefaultUI={true}
        >
          {renderMarkers(false)}
        </Map>
      )}
    </div>
  )
})

export default MapView
