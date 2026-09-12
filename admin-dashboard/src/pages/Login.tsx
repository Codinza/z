import { useState } from 'react'
import { LogIn } from 'lucide-react'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  return (
    <div className="min-h-screen bg-black-900 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="card p-8">
          <div className="text-center mb-8">
            <div className="w-12 h-12 bg-gradient-orange rounded-lg flex items-center justify-center mx-auto mb-4">
              <LogIn className="w-6 h-6 text-white" />
            </div>
            <h1 className="text-2xl font-bold text-white">RideFlow</h1>
            <p className="text-gray-400 mt-2">لوحة التحكم الإدارية</p>
          </div>
          <form className="space-y-4">
            <div>
              <label className="text-sm text-gray-300">البريد الإلكتروني</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="input-field w-full mt-1"
                placeholder="admin@example.com"
              />
            </div>
            <div>
              <label className="text-sm text-gray-300">كلمة المرور</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="input-field w-full mt-1"
                placeholder="••••••••"
              />
            </div>
            <button type="submit" className="btn-primary w-full mt-6">
              تسجيل الدخول
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
