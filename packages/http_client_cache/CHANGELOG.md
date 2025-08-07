## 1.0.2

### Improvements
- 📝 **Enhanced Logger Messages**: Made all cache logging messages consistent, developer-friendly, and informative
- 🔗 **Added Request URLs**: All logger messages now include the request URL for better debugging context
- 🎯 **Consistent Message Style**: Unified tone and format across all cache-related log messages

### Logger Message Examples
- `Cache hit for https://api.example.com/data`
- `Cache miss for https://api.example.com/data`
- `Cache entry expired for https://api.example.com/data`
- `Skipping cache for private response: https://api.example.com/data`
- `Skipping cache due to no-store directive: https://api.example.com/data`
- `Skipping cache due to Vary: * header: https://api.example.com/data`

### Technical Improvements
- 🛠️ **Better Debugging Experience**: Easier to track cache behavior per URL
- 📊 **Improved Error Context**: Cache write failures now include request URLs
- 🎨 **Cleaner Message Format**: Removed redundant text and improved readability

## 1.0.1

- add `noCache` and `noStore` boolean parameters to `CacheControl` factory constructors to preserve important cache directives when transforming response headers
- update libs and protobuf Dart files

## 1.0.0

- Initial version.
