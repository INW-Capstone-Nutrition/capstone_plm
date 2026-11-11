import { lazy, Suspense } from 'react'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import { AppShell } from '@/components/layout/app-shell'

const DashboardPage = lazy(() => import('@/features/dashboard/dashboard-page').then(module => ({ default: module.DashboardPage })))
const ExplorerPage = lazy(() => import('@/features/explorer/explorer-page').then(module => ({ default: module.ExplorerPage })))
const AdministrationPage = lazy(() => import('@/features/forms/administration-page').then(module => ({ default: module.AdministrationPage })))
const ReportsPage = lazy(() => import('@/features/forms/reports-page').then(module => ({ default: module.ReportsPage })))

function page(element: React.ReactNode) {
  return <Suspense fallback={<div className="h-80 animate-pulse rounded-2xl bg-white" />}>{element}</Suspense>
}

const router = createBrowserRouter([
  {
    path: '/',
    element: <AppShell />,
    children: [
      { index: true, element: page(<DashboardPage />) },
      { path: 'formulas', element: page(<ExplorerPage initialTab="formulas" />) },
      { path: 'materials', element: page(<ExplorerPage initialTab="materials" />) },
      { path: 'specifications', element: page(<ExplorerPage initialTab="materials" />) },
      { path: 'reports', element: page(<ReportsPage />) },
      { path: 'administration', element: page(<AdministrationPage />) },
    ],
  },
])

export default function App() {
  return <RouterProvider router={router} />
}
