import logger from '../utils/logger.js';

export const getPageContent = (req, res) => {
  const { pageId } = req.params;

  // Static mock content for now. Later can be moved to DB if needed.
  const pages = {
    terms: {
      title: 'الشروط والأحكام',
      content: 'مرحباً بك في تطبيقنا. باستخدامك لهذا التطبيق، فإنك توافق على الشروط التالية...\n\n1. الالتزام بقواعد المرور.\n2. الدفع عند انتهاء الرحلة.\n3. احترام السائق والركاب.',
    },
    privacy: {
      title: 'سياسة الخصوصية',
      content: 'نحن نهتم بخصوصيتك. نقوم بجمع بيانات الموقع الجغرافي فقط أثناء استخدام التطبيق لضمان وصول السائق إليك. لا نشارك بياناتك مع أطراف ثالثة لأغراض دعائية.',
    },
    about: {
      title: 'عن التطبيق',
      content: 'تطبيق RideFlow هو أحدث تطبيق لحجز الرحلات والتنقل بسهولة وأمان. الإصدار 1.0.0',
    },
    help: {
      title: 'المساعدة',
      content: 'هل تواجه مشكلة؟\n- لحل مشاكل الدفع، تأكد من تحديث التطبيق.\n- للإبلاغ عن سائق، استخدم زر الإبلاغ في الرحلات السابقة.',
    },
  };

  const page = pages[pageId];
  if (!page) {
    return res.status(404).json({ error: 'Page not found' });
  }

  res.json(page);
};

export const submitContactMessage = (req, res) => {
  const { name, email, message } = req.body;
  if (!name || !email || !message) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  
  // In a real app, save to DB or send email
  logger.info('New contact message received', { name, email, message });
  
  res.status(201).json({ success: true, message: 'تم إرسال رسالتك بنجاح' });
};
