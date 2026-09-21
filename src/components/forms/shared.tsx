import { ACCENTS, COVERS } from '../../store'

/** 时长输入：数字 + 单位（分钟 / 小时） */
export function DurationField({
  text,
  unit,
  onText,
  onUnit,
}: {
  text: string
  unit: 'min' | 'hour'
  onText: (v: string) => void
  onUnit: (u: 'min' | 'hour') => void
}) {
  return (
    <div className="input-row">
      <input
        className="input"
        type="number"
        inputMode="decimal"
        min={0}
        step={unit === 'hour' ? 0.5 : 5}
        placeholder={unit === 'hour' ? '1.5' : '45'}
        value={text}
        onChange={(e) => onText(e.target.value)}
      />
      <div className="chips">
        <button
          type="button"
          className={`chip${unit === 'min' ? ' active' : ''}`}
          onClick={() => onUnit('min')}
        >
          分钟
        </button>
        <button
          type="button"
          className={`chip${unit === 'hour' ? ' active' : ''}`}
          onClick={() => onUnit('hour')}
        >
          小时
        </button>
      </div>
    </div>
  )
}

export function toMinutes(text: string, unit: 'min' | 'hour'): number | undefined {
  const n = Number.parseFloat(text)
  if (!Number.isFinite(n) || n <= 0) return undefined
  return Math.round(unit === 'hour' ? n * 60 : n)
}

/** 封面 emoji 选择 */
export function CoverPicker({
  value,
  onChange,
}: {
  value: string
  onChange: (v: string) => void
}) {
  return (
    <div className="chips">
      {COVERS.map((c) => (
        <button
          key={c}
          type="button"
          className={`chip emoji${value === c ? ' active' : ''}`}
          onClick={() => onChange(c)}
        >
          {c}
        </button>
      ))}
    </div>
  )
}

/** 主题色选择 */
export function AccentPicker({
  value,
  onChange,
}: {
  value: string
  onChange: (v: string) => void
}) {
  return (
    <div className="chips" style={{ alignItems: 'center' }}>
      {ACCENTS.map((a) => (
        <button
          key={a}
          type="button"
          className={`swatch${value === a ? ' active' : ''}`}
          style={{ background: a }}
          onClick={() => onChange(a)}
          aria-label={`颜色 ${a}`}
        />
      ))}
    </div>
  )
}
