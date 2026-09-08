import { defineConfig } from '@playwright/test';
export default defineConfig({ testDir: './e2e', outputDir: '../test-results', timeout: 40_000, workers: 1, use: { baseURL: process.env.APP_URL || 'http://localhost:8081', headless: true, viewport: {width: 1440, height: 1000}, screenshot: 'only-on-failure', trace: 'retain-on-failure' }, reporter: 'list' });
