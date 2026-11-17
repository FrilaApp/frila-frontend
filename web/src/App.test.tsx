import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { App } from './App.tsx'

describe('App', () => {
  it('mostra o título do produto', () => {
    render(<App />)
    expect(screen.getByRole('heading', { level: 1, name: 'Frila' })).toBeInTheDocument()
  })
})
