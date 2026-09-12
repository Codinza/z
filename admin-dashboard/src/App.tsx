import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import DashboardLayout from '@/components/layout/DashboardLayout'
import Dashboard from '@/pages/Dashboard'
import Shipments from '@/pages/Shipments'
import ShipmentDetail from '@/pages/ShipmentDetail'
import Drivers from '@/pages/Drivers'
import Customers from '@/pages/Customers'
import Limousine from '@/pages/Limousine'
import LiveTracking from '@/pages/LiveTracking'
import Payments from '@/pages/Payments'
import Reports from '@/pages/Reports'
import Notifications from '@/pages/Notifications'
import News from '@/pages/News'
import Employees from '@/pages/Employees'
import Settings from '@/pages/Settings'
import Login from '@/pages/Login'

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route element={<DashboardLayout />}>
          <Route path="/" element={<Dashboard />} />
          <Route path="/shipments" element={<Shipments />} />
          <Route path="/shipments/:id" element={<ShipmentDetail />} />
          <Route path="/drivers" element={<Drivers />} />
          <Route path="/customers" element={<Customers />} />
          <Route path="/limousine" element={<Limousine />} />
          <Route path="/tracking" element={<LiveTracking />} />
          <Route path="/payments" element={<Payments />} />
          <Route path="/reports" element={<Reports />} />
          <Route path="/notifications" element={<Notifications />} />
          <Route path="/news" element={<News />} />
          <Route path="/employees" element={<Employees />} />
          <Route path="/settings" element={<Settings />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
