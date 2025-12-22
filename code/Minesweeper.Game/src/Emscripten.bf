using System;
using System.Interop;

#if BF_PLATFORM_WASM
namespace Minesweeper.Game;

static
{
	[CLink, CallingConvention(.Stdcall)]
	public static extern void emscripten_console_log(char8* utf8String);

	public function void em_callback_func();

	[CLink, CallingConvention(.Stdcall)]
	public static extern void emscripten_set_main_loop(em_callback_func func, int32 fps, int32 simulateInfinteLoop);

	[CLink, CallingConvention(.Stdcall)]
	public static extern int32 emscripten_set_main_loop_timing(int32 mode, int32 value);

	[CLink, CallingConvention(.Stdcall)]
	public static extern double emscripten_get_now();

	[CLink, CallingConvention(.Stdcall)]
	public static extern void emscripten_run_script(char8* script);

	[CLink, CallingConvention(.Stdcall)]
	public static extern char8* emscripten_run_script_string(char8* script);

	public typealias EM_UTF8 = c_char;
	public typealias pthread_t = c_ulong;
	public const int EM_HTML5_LONG_STRING_LEN_BYTES = 128;

	[CRepr]
	public struct EmscriptenFocusEvent
	{
		public EM_UTF8[EM_HTML5_LONG_STRING_LEN_BYTES] nodeName;
		public EM_UTF8[EM_HTML5_LONG_STRING_LEN_BYTES] id;
	}

	public function void em_focus_callback_func(c_int eventType, EmscriptenFocusEvent* focusEvent, void* userData);

	[CLink, CallingConvention(.Stdcall)]
	public static extern EMSCRIPTEN_RESULT emscripten_set_focus_callback(char8* target, void* userData, bool useCapture, em_focus_callback_func callback, pthread_t targetThread);
	[CLink, CallingConvention(.Stdcall)]
	public static extern EMSCRIPTEN_RESULT emscripten_set_blur_callback(char8* target, void* userData, bool useCapture, em_focus_callback_func callback, pthread_t targetThread);

	[CRepr]
	public struct emscripten_fetch_attr_t
	{
		// 'POST', 'GET', etc.
		public char8[32] requestMethod;

		// Custom data that can be tagged along the process.
		public void* userData;

		// void (*onsuccess)(struct emscripten_fetch_t *fetch);
		// void (*onerror)(struct emscripten_fetch_t *fetch);
		// void (*onprogress)(struct emscripten_fetch_t *fetch);
		// void (*onreadystatechange)(struct emscripten_fetch_t *fetch);

		public function void(emscripten_fetch_t* fetch) onsuccess;
		public function void(emscripten_fetch_t* fetch) onerror;
		public function void(emscripten_fetch_t* fetch) onprogress;
		public function void(emscripten_fetch_t* fetch) onreadystatechange;

		// EMSCRIPTEN_FETCH_* attributes
		public uint32 attributes;

		// Specifies the amount of time the request can take before failing due to a
		// timeout.
		public uint32 timeoutMSecs;

		// Indicates whether cross-site access control requests should be made using
		// credentials.
		public bool withCredentials;

		// Specifies the destination path in IndexedDB where to store the downloaded
		// content body. If this is empty, the transfer is not stored to IndexedDB at
		// all.  Note that this struct does not contain space to hold this string, it
		// only carries a pointer.
		// Calling emscripten_fetch() will make an internal copy of this string.
		public c_char* destinationPath;

		// Specifies the authentication username to use for the request, if necessary.
		// Note that this struct does not contain space to hold this string, it only
		// carries a pointer.
		// Calling emscripten_fetch() will make an internal copy of this string.
		public c_char* userName;

		// Specifies the authentication username to use for the request, if necessary.
		// Note that this struct does not contain space to hold this string, it only
		// carries a pointer.
		// Calling emscripten_fetch() will make an internal copy of this string.
		public c_char* password;

		// Points to an array of strings to pass custom headers to the request. This
		// array takes the form
		// {"key1", "value1", "key2", "value2", "key3", "value3", ..., 0 }; Note
		// especially that the array needs to be terminated with a null pointer.
		public c_char** requestHeaders;

		// Pass a custom MIME type here to force the browser to treat the received
		// data with the given type.
		public c_char* overriddenMimeType;

		// If non-zero, specifies a pointer to the data that is to be passed as the
		// body (payload) of the request that is being performed. Leave as zero if no
		// request body needs to be sent.  The memory pointed to by this field is
		// provided by the user, and needs to be valid throughout the duration of the
		// fetch operation. If passing a non-zero pointer into this field, make sure
		// to implement *both* the onsuccess and onerror handlers to be notified when
		// the fetch finishes to know when this memory block can be freed. Do not pass
		// a pointer to memory on the stack or other temporary area here.
		public c_char* requestData;

		// Specifies the length of the buffer pointed by 'requestData'. Leave as 0 if
		// no request body needs to be sent.
		public c_size requestDataSize;
	}

	[CRepr]
	public struct emscripten_fetch_t
	{
	  // Unique identifier for this fetch in progress.
	  public uint32 id;

	  // Custom data that can be tagged along the process.
	  public void* userData;

	  // The remote URL set in the original request.
	  public c_char* url;

	  // In onsuccess() handler:
	  //   - If the EMSCRIPTEN_FETCH_LOAD_TO_MEMORY attribute was specified for the
	  //     transfer, this points to the body of the downloaded data. Otherwise
	  //     this will be null.
	  // In onprogress() handler:
	  //   - If the EMSCRIPTEN_FETCH_STREAM_DATA attribute was specified for the
	  //     transfer, this points to a partial chunk of bytes related to the
	  //     transfer. Otherwise this will be null.
	  // The data buffer provided here has identical lifetime with the
	  // emscripten_fetch_t object itself, and is freed by calling
	  // emscripten_fetch_close() on the emscripten_fetch_t pointer.
	  public c_char* *data;

	  // Specifies the length of the above data block in bytes. When the download
	  // finishes, this field will be valid even if EMSCRIPTEN_FETCH_LOAD_TO_MEMORY
	  // was not specified.
	  public uint64 numBytes;

	  // If EMSCRIPTEN_FETCH_STREAM_DATA is being performed, this indicates the byte
	  // offset from the start of the stream that the data block specifies. (for
	  // onprogress() streaming XHR transfer, the number of bytes downloaded so far
	  // before this chunk)
	  public uint64 dataOffset;

	  // Specifies the total number of bytes that the response body will be.
	  // Note: This field may be zero, if the server does not report the
	  // Content-Length field.
	  public uint64 totalBytes;

	  // Specifies the readyState of the XHR request:
	  // 0: UNSENT: request not sent yet
	  // 1: OPENED: emscripten_fetch has been called.
	  // 2: HEADERS_RECEIVED: emscripten_fetch has been called, and headers and
	  //    status are available.
	  // 3: LOADING: download in progress.
	  // 4: DONE: download finished.
	  // See https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/readyState
	  public c_ushort readyState;

	  // Specifies the status code of the response.
	  public c_ushort status;

	  // Specifies a human-readable form of the status code.
	  public c_char[64] statusText;

	  // For internal use only.
	  public emscripten_fetch_attr_t __attributes;

	  // The response URL set by the fetch. It will be null until HEADERS_RECEIVED
	  // readyState in async, or until completion in sync.
	  public char8* responseUrl;
	};

	public typealias EMSCRIPTEN_RESULT = c_int;

	[CLink, CallingConvention(.Stdcall)]
	public static extern void emscripten_fetch_attr_init(emscripten_fetch_attr_t* attr);

	[CLink, CallingConvention(.Stdcall)]
	public static extern emscripten_fetch_t* emscripten_fetch(emscripten_fetch_attr_t* attr, char8* url);

	[CLink, CallingConvention(.Stdcall)]
	public static extern EMSCRIPTEN_RESULT emscripten_fetch_close(emscripten_fetch_t* fetch);
}
#endif