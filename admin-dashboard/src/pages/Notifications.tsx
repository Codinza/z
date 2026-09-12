import { Bell } from 'lucide-react'

export default function Notifications() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white">الإشعارات</h1>
        <p className="text-gray-400 mt-1">مركز الإشعارات والتنبيهات</p>
      </div>
      <div className="card p-6">
        <div className="text-center py-12">
          <Bell className="w-12 h-12 text-orange-500/50 mx-auto mb-3" />
          <p className="text-gray-400">لا توجد إشعارات جديدة</p>
        </div>
      </div>
    </div>
  )
}
