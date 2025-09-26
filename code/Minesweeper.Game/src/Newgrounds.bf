using System;
using BJSON;
using BJSON.Enums;

namespace Minesweeper;

public static class Newgrounds
{
#if NEWGROUNDS
	public class Session
	{
		public String ID = new .() ~ delete _;
		public String PassportURL = new .() ~ delete _;
	}

	public const String NG_GATEWAY = "https://www.newgrounds.io/gateway_v3.php";
	public const String APP_ID = "60887:rrikEyZ0";

	public const int SCORE_BOARD_ID = 15239;
	public const int COMBO_BOARD_ID = 15240;

	private static Session m_session = null ~ if (_ != null) delete _;

	[CRepr]
	private struct Thecallbacks
	{
		public function void(emscripten_fetch_t* fetch) OnSuccess;
		public function void(emscripten_fetch_t* fetch) OnError;
	}

	static void OnSuccess(emscripten_fetch_t* fetch)
	{
#if DEBUG
		let response = scope String((char8*)fetch.data, (int)(fetch.numBytes / sizeof(char8)));
		Console.WriteLine(response);
#endif

		let fun = (Thecallbacks*)fetch.userData; 
		fun.OnSuccess(fetch);

		// I guess we should delete these because they were allocated on the heap?
		// Idk, emscripten doesn't seem to complain...?
		delete fun;
		delete fetch.__attributes.requestData;
		emscripten_fetch_close(fetch);
	}

	static void OnError(emscripten_fetch_t* fetch)
	{
		let fun = (Thecallbacks*)fetch.userData; 
		fun.OnError(fetch);

		// I guess we should delete these because they were allocated on the heap?
		// Idk, emscripten doesn't seem to complain...?
		delete fun;
		delete fetch.__attributes.requestData;
		emscripten_fetch_close(fetch);
	}

	private static void postRequest(String jsonData, function void(emscripten_fetch_t* fetch) onSuccess, function void(emscripten_fetch_t* fetch) onError)
	{
		// NEVER EVER TOUCH STRINGS AFTER CREATING THEM
		// IT BREAKS THEM!!!
		// DON'T EVEN LOG WITH THEM!!!
		// let jsonData = scope String(jsonDataa);

		emscripten_fetch_attr_t attr;
		emscripten_fetch_attr_init(&attr);

		let callbacks = new Thecallbacks()
		{
			OnSuccess = onSuccess,
			OnError = onError
		};
		attr.userData = callbacks;

		attr.requestMethod = "POST";
		attr.attributes = 1;

		let postData = new $"request={jsonData}";

		// attr.requestData = jsonData;

		// !!!
		// DATA PASSED HERE MUST BE ALLOCATED ON THE HEAP!
		// !!!
		attr.requestData = postData;
		attr.requestDataSize = (uint)postData.Length;

		attr.onsuccess = => OnSuccess;
		attr.onerror = => OnError;

		/// NOTE NOTE NOTE!!!
		/// THE ARRAY NEEEEDS TO BE TERMINATED WITH A NULL POINTER
		/// SPENT 3 HOURS FIGURING THIS OUT!!! !!!READ THE DOCS, KIDS!!!
		char8*[?] headers = .(
			// "Content-Type", "application/json",
			"Content-Type", "application/x-www-form-urlencoded",
			null
		);

		attr.requestHeaders = &headers;

		emscripten_fetch(&attr, NG_GATEWAY);

	}
#endif
	public static void Init()
	{
	}

	public static void Login()
	{
#if NEWGROUNDS
		let sessionID = StringView(emscripten_run_script_string("""
			(() => {
				const params = new URLSearchParams(window.location.search);
				return params.get('ngio_session_id') || '';
			})()
			"""));

		if (!sessionID.IsEmpty && !sessionID.IsNull)
		{
			let jsonData = scope $"""
			\{
			  "app_id": "{APP_ID}",
			  "session_id": "{sessionID}",
			  "call": \{
			    "component": "App.checkSession",
			    "parameters": \{
			    \}
			  \}
			\}
			""";

			// NEVER EVER TOUCH STRINGS AFTER CREATING THEM
			// IT BREAKS THEM!!!

			void onSuccess(emscripten_fetch_t* fetch)
			{
				let response = scope String((char8*)fetch.data, (int)(fetch.numBytes / sizeof(char8)));

				let t = Json.Deserialize(response);
				if (t case .Ok(let json))
				{
					defer json.Dispose();

					if (json["success"] == true)
					{
						let data = json["result"]["data"];
						let session = data["session"];

						m_session = new .();
						m_session.ID.Set(session["id"]);

#if DEBUG					
						Console.WriteLine(response);
#endif
					}
				}
				else if (t case .Err(let err))
				{
#if DEBUG
					Console.WriteLine(response);
					Console.WriteLine(err.GetType().GetName(.. scope .()));
#endif
				}
			}

			void onError(emscripten_fetch_t* fetch)
			{
			}

			postRequest(jsonData, (fetch) => onSuccess(fetch), (fetch) => onError(fetch));
		}
		else
		{
#if DEBUG
			let jsonData = scope $"""
				\{
				    "app_id": "{APP_ID}",
				    "call": \{
				        "component": "App.startSession",
				        "parameters": \{\}
				    \}
				\}
				""";

			void onSuccess(emscripten_fetch_t* fetch)
			{
				let response = scope String((char8*)fetch.data, (int)(fetch.numBytes / sizeof(char8)));

				let t = Json.Deserialize(response);
				if (t case .Ok(let json))
				{
					defer json.Dispose();

					let data = json["result"]["data"];
					let session = data["session"];

					m_session = new .();
					m_session.ID.Set(session["id"]);
					m_session.PassportURL.Set(session["passport_url"]);

					Console.WriteLine(response);
					Console.WriteLine(m_session.PassportURL);
				}
				else if (t case .Err(let err))
				{
					Console.WriteLine(response);
					Console.WriteLine(err.GetType().GetName(.. scope .()));
				}
			}

			void onError(emscripten_fetch_t* fetch)
			{
			}

			postRequest(jsonData, (fetch) => onSuccess(fetch), (fetch) => onError(fetch));
#endif
		}
#endif
	}

	public static void PostScore(int points, int combo)
	{
#if NEWGROUNDS
		if (m_session == null)
			return;

		let jsonData = scope $"""
			\{
			  "app_id": "{APP_ID}",
			  "session_id": "{m_session.ID}",
			  "execute": [
				\{
				    "component": "ScoreBoard.postScore",
				    "parameters": \{
				      "id": {SCORE_BOARD_ID},
				      "value": {points}
				    \}
				\}
			  ]
			\}
			""";

		void onSuccess(emscripten_fetch_t* fetch)
		{
			let response = scope String((char8*)fetch.data, (int)(fetch.numBytes / sizeof(char8)));
#if DEBUG
			Console.WriteLine(response);
#endif

			let t = Json.Deserialize(response);
			if (t case .Ok(let json))
			{
				defer json.Dispose();
			}
			else if (t case .Err(let err))
			{
#if DEBUG
				Console.WriteLine(response);
				Console.WriteLine(err.GetType().GetName(.. scope .()));
#endif
			}
		}

		void onError(emscripten_fetch_t* fetch)
		{
		}

		postRequest(jsonData, (fetch) => onSuccess(fetch), (fetch) => onError(fetch));
#endif
	}

	/*
	private static int WriteFunc(void* ptr, int size, int nmemb, void* userdata)
	{
	    int realSize = size * nmemb;
	    if (userdata != null)
	    {
	        let buf = (String)Internal.UnsafeCastToObject(userdata);
			let str = (char8*)ptr;
	        buf.Append(str);
	    }
	    return (int)realSize;
	}

	private static function int(void* ptr, int size, int count, void* ctx) writeFunc = => WriteFunc;
	*/
}
