import { expect, test } from '@playwright/test'

test('abre a página sem erro de console e mostra o título', async ({ page }) => {
  const erros: string[] = []
  page.on('console', (msg) => {
    if (msg.type() === 'error' || msg.type() === 'warning') erros.push(msg.text())
  })
  page.on('pageerror', (e) => erros.push(e.message))

  await page.goto('/')

  await expect(page.getByRole('heading', { level: 1, name: 'Frila' })).toBeVisible()
  expect(erros).toEqual([])
})
