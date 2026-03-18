const fs = require('fs');
const path = require('path');
const files = [
  'lib/features/auth/presentation/pages/persona_creation_screen.dart',
  'lib/features/auth/presentation/pages/otp_verification_screen.dart',
  'lib/features/auth/presentation/pages/reset_password_screen.dart',
  'lib/features/auth/presentation/pages/forgot_password_screen.dart'
];

files.forEach(file => {
  const absolutePath = path.resolve('d:/flutter_app/SafeSpace', file);
  if (fs.existsSync(absolutePath)) {
    let content = fs.readFileSync(absolutePath, 'utf8');
    const newContent = content.replace(/\.withOpacity\(([^)]+)\)/g, '.withValues(alpha: $1)');
    if (content !== newContent) {
      fs.writeFileSync(absolutePath, newContent, 'utf8');
      console.log(`Fixed ${file}`);
    } else {
      console.log(`No fixes needed for ${file}`);
    }
  } else {
    console.log(`File not found: ${file}`);
  }
});
