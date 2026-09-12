import { Plus } from 'lucide-react'

export default function Employees() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">الموظفين والصلاحيات</h1>
          <p className="text-gray-400 mt-1">إدارة الموظفين والأدوار والصلاحيات</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors font-medium">
          <Plus className="w-5 h-5" />
          موظف جديد
        </button>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        {['Super Admin', 'Manager', 'Support', 'Finance', 'Operations'].map((role) => (
          <div key={role} className="card p-4 text-center">
            <p className="text-white font-medium">{role}</p>
            <p className="text-gray-400 text-sm mt-2">0 موظفين</p>
          </div>
        ))}
      </div>
    </div>
  )
}
