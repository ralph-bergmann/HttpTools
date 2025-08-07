## 1.0.3

### Improvements
- 🚨 **Enhanced Stale Content Logging**: Added specific log messages for stale-while-revalidate and stale-if-error scenarios
- 📖 **Improved Documentation**: Updated README with comprehensive debugging section and stale-if-error feature documentation

### New Logger Messages
- `Serving stale content while revalidating for https://api.example.com/data` - Shows when stale-while-revalidate is active
- `Serving stale content due to network error for https://api.example.com/data` - Shows when stale-if-error provides fallback

### Technical Improvements
- 🔍 **Better Cache Visibility**: Developers can now see exactly when and why stale content is being served
- 🛡️ **Resilience Insights**: Clear indication when cache provides error recovery through stale content
- 📊 **Performance Transparency**: Understand when background revalidation occurs

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
