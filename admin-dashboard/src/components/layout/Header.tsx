import { Search, Bell, HelpCircle, Settings } from 'lucide-react'

export default function Header() {
  return (
    <header className="bg-black-850 border-b border-gray-700 px-6 py-4 flex items-center justify-between sticky top-0 z-40 shadow-md">
      {/* Search */}
      <div className="flex-1 max-w-md">
        <div className="relative">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            type="text"
            placeholder="ابحث عن شحنة، عميل، سائق..."
            className="input-field w-full pr-10"
          />
        </div>
      </div>

      {/* Right Actions */}
      <div className="flex items-center gap-4 mr-6">
        {/* Notifications */}
        <button className="relative p-2 text-gray-400 hover:text-gray-200 transition-colors">
          <Bell className="w-5 h-5" />
          <span className="absolute top-1 right-1 w-2 h-2 bg-orange-500 rounded-full"></span>
        </button>

        {/* Help */}
        <button className="p-2 text-gray-400 hover:text-gray-200 transition-colors">
          <HelpCircle className="w-5 h-5" />
        </button>

        {/* Settings */}
        <button className="p-2 text-gray-400 hover:text-gray-200 transition-colors">
          <Settings className="w-5 h-5" />
        </button>

        {/* Divider */}
        <div className="w-px h-6 bg-gray-700"></div>

        {/* Admin Profile */}
        <button className="flex items-center gap-2 px-3 py-2 hover:bg-black-800 rounded-lg transition-colors">
          <img
            src="https://via.placeholder.com/32"
            alt="Admin"
            className="w-8 h-8 rounded-full"
          />
          <span className="text-sm font-medium hidden md:inline">مدير</span>
        </button>
      </div>
    </header>
  )
}
