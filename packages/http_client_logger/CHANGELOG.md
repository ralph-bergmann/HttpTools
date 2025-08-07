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
