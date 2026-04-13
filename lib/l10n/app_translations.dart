import 'package:flutter/material.dart';

class AppTranslations {
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'settings': 'Settings',
      'appearance': 'Appearance',
      'dark_mode': 'Dark Mode',
      'security': 'Security',
      'biometric': 'Biometric Login',
      'app_lock': 'App Lock (PIN)',
      'permissions': 'Permissions',
      'camera': 'Camera Access',
      'location': 'Location Services',
      'colors': 'Colors',
      'primary_color': 'Primary Color',
      'typography': 'Typography',
      'font_style': 'Font Style',
      'font_size': 'Font Size',
      'ui_components': 'UI Components',
      'button_roundness': 'Button Roundness',
      'language': 'Language',
    },
    'hi': {
      'settings': 'सेटिंग्स',
      'appearance': 'दिखावट',
      'dark_mode': 'डार्क मोड',
      'security': 'सुरक्षा',
      'biometric': 'बायोमेट्रिक लॉगिन',
      'app_lock': 'ऐप लॉक (पिन)',
      'permissions': 'अनुमतियां',
      'camera': 'कैमरा एक्सेस',
      'location': 'स्थान सेवाएं',
      'colors': 'रंग',
      'primary_color': 'मुख्य रंग',
      'typography': 'टाइपोग्राफी',
      'font_style': 'फ़ॉन्ट शैली',
      'font_size': 'फ़ॉन्ट आकार',
      'ui_components': 'यूआई घटक',
      'button_roundness': 'बटन गोलाई',
      'language': 'भाषा',
    },
    'pa': {
      'settings': 'ਸੈਟਿੰਗਾਂ',
      'appearance': 'ਦਿੱਖ',
      'dark_mode': 'ਡਾਰਕ ਮੋਡ',
      'security': 'ਸੁਰੱਖਿਆ',
      'biometric': 'ਬਾਇਓਮੈਟ੍ਰਿਕ ਲੌਗਇਨ',
      'app_lock': 'ਐਪ ਲਾਕ (ਪਿੰਨ)',
      'permissions': 'ਪਰਮਿਸ਼ਨ',
      'camera': 'ਕੈਮਰਾ ਪਹੁੰਚ',
      'location': 'ਟਿਕਾਣਾ ਸੇਵਾਵਾਂ',
      'colors': 'ਰੰਗ',
      'primary_color': 'ਮੁੱਖ ਰੰਗ',
      'typography': 'ਟਾਈਪੋਗ੍ਰਾਫੀ',
      'font_style': 'ਫੌਂਟ ਸਟਾਈਲ',
      'font_size': 'ਫੌਂਟ ਦਾ ਆਕਾਰ',
      'ui_components': 'UI ਭਾਗ',
      'button_roundness': 'ਬਟਨ ਗੋਲਾਈ',
      'language': 'ਭਾਸ਼ਾ',
    },
  };

  static String translate(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return _translations[locale]?[key] ?? _translations['en']![key]!;
  }
}
