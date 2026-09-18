import { Link, useLocation } from 'react-router-dom'
import {
  Home,
  Package,
  Users,
  UserCheck,
  MapPin,
  DollarSign,
  BarChart3,
  Bell,
  Settings,
  LogOut,
  Truck,
  Zap,
} from 'lucide-react'

const navItems = [
  { label: 'الرئيسية', icon: Home, path: '/' },
  { label: 'الرحلات', icon: Package, path: '/shipments' },
  { label: 'السائقين', icon: UserCheck, path: '/drivers' },
  { label: 'العملاء', icon: Users, path: '/customers' },
  { label: 'التوصيل', icon: MapPin, path: '/tracking' },
  { label: 'شحن البضائع', icon: Truck, path: '/shipments' },
  { label: 'المدفوعات', icon: DollarSign, path: '/payments' },
  { label: 'التقارير', icon: BarChart3, path: '/reports' },
  { label: 'الإشعارات', icon: Bell, path: '/notifications' },
  { label: 'الإعدادات', icon: Settings, path: '/settings' },
]

export default function Sidebar() {
  const location = useLocation()

  return (
    <aside className="fixed right-0 top-0 w-64 h-screen bg-black-850 border-l border-gray-700 flex flex-col shadow-xl">
      <div className="p-6 border-b border-gray-700">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 bg-gradient-orange rounded-lg flex items-center justify-center">
            <Zap className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-xl font-bold text-white">RideFlow</h1>
            <p className="text-xs text-gray-400">لوحة الإدارة</p>
          </div>
        </div>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-4">
        <div className="space-y-2">
          {navItems.map((item) => {
            const Icon = item.icon
            const isActive = location.pathname === item.path

            return (
              <Link
                key={`${item.label}-${item.path}`}
                to={item.path}
                className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 ${
                  isActive
                    ? 'bg-orange-500/10 text-orange-400 border-r-2 border-orange-500 shadow-lg shadow-orange-500/10'
                    : 'text-gray-300 hover:bg-black-800 hover:text-white'
                }`}
              >
                <Icon className="w-5 h-5 flex-shrink-0" />
                <span className="text-sm font-medium">{item.label}</span>
              </Link>
            )
          })}
        </div>
      </nav>

      <div className="border-t border-gray-700 p-4 space-y-3">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-orange-500 rounded-full flex items-center justify-center text-white font-bold">
            أ
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-white truncate">مدير النظام</p>
            <p className="text-xs text-gray-400">Ahmed Admin</p>
          </div>
        </div>
        <button className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-red-500/10 text-red-400 hover:bg-red-500/20 rounded-xl transition-colors text-sm font-medium">
          <LogOut className="w-4 h-4" />
          تسجيل الخروج
        </button>
      </div>
    </aside>
  )
}
