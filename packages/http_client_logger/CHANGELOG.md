## 1.1.2

### Features
- 📊 **Human-Readable Binary Content Logging**: Binary content now shows MIME type and smart size formatting
- 📏 **Smart Size Formatting**: Automatically formats sizes as bytes, KB, or MB for better readability
- 🎯 **Enhanced Binary Messages**: Format changed to `<binary content of {mime-type} with a length of {human-size}>`

### Technical Improvements  
- 🔧 **Added `_formatBytes()` method**: Intelligent byte size formatting (bytes/KB/MB)
- 🎨 **Improved Binary Content Display**: Shows MIME type alongside human-readable file sizes
- 📝 **Better Log Readability**: Cleaner binary content messages without raw byte counts

### Example Output
- Small files: `<binary content of image/jpeg with a length of 833 bytes>`
- Medium files: `<binary content of image/png with a length of 1.5KB>`  
- Large files: `<binary content of video/mp4 with a length of 2.3MB>`

## 1.1.1

### Features
- 🆔 **Improved Request ID System**: Replaced UUID with custom short ID generation
- 🎯 **Consistent IDs**: Request IDs are now identical in HTTP headers and log output
- 📝 **Enhanced Log Format**: Added request ID prefixes to all log lines for better tracking
- 🔍 **Concurrent Request Support**: Easy to follow multiple simultaneous requests

### Technical Improvements
- ⚡ **Removed UUID dependency**: Custom 8-character ID generation using timestamp + random bits
- 🚀 **Better Performance**: Faster ID generation with guaranteed uniqueness
- 🎨 **Improved Log Formatting**: Consistent indentation and clear request/response boundaries
- 🛠️ **Better Error Context**: Error messages now include request IDs for easier debugging

### Breaking Changes
- None - fully backward compatible

## 1.1.0

### Features
- ✨ Added `Level.body` support for logging HTTP request and response bodies
- 🚀 Enhanced request body logging for different request types (`Request`, `MultipartRequest`)
- 📝 Improved response body logging with proper stream handling using `StreamSplitter`
- 🔍 Added support for logging multipart form fields and file information
- ⚡ Implemented proper async handling to ensure correct log ordering

### Technical Improvements
- Added `async` package dependency for `StreamSplitter` functionality
- Enhanced error handling for body reading operations
- Improved UTF-8 decoding with malformed character support
- Added comprehensive documentation and performance warnings

### Documentation
- 📚 Updated README with logging level explanations and performance considerations
- ⚠️ Added performance warnings for body-level logging
- 🛠️ Enhanced code examples with different logging levels

## 1.0.0

- Initial version.
