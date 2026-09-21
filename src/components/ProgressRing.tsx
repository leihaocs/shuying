import type { ReactNode } from 'react'

interface Props {
  value: number
  size?: number
  stroke?: number
  children?: ReactNode
}

export default function ProgressRing({
  value,
  size = 100,
  stroke = 9,
  children,
}: Props) {
  const v = Math.max(0, Math.min(100, value))
  const r = (size - stroke) / 2
  const circumference = 2 * Math.PI * r
  const offset = circumference * (1 - v / 100)

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ flex: 'none' }}>
      <defs>
        <linearGradient id="ringGrad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="var(--accent)" />
          <stop offset="100%" stopColor="var(--accent-2)" />
        </linearGradient>
      </defs>
      <circle
        className="ring-bg"
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        strokeWidth={stroke}
      />
      <circle
        className="ring-fg"
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        strokeWidth={stroke}
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={offset}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
      />
      <text
        className="ring-text"
        x="50%"
        y="50%"
        textAnchor="middle"
        dominantBaseline="central"
      >
        {children ?? `${Math.round(v)}%`}
      </text>
    </svg>
  )
}
