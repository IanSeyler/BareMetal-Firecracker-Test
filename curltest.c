// curltest.c -- a minimal demo of libcurl's easy interface running as a
// BareMetal app: fetches FETCH_URL and prints the HTTP status code and
// response body. build with build-app.sh.
//
// This is also a valid *nix program of course.
//
// Unlike crawler.c/https_crawler.c (which speak raw HTTP over
// port/net_shim.c's sockets, and TLS over port/tls_shim.c's mbedTLS
// wrapper, by hand), this goes through the real, unmodified libcurl
// (see scripts/get-curl.sh, port/curl_port/curl_config.h) -- socket()/
// connect()/send()/recv() calls still end up in the exact same
// net_shim.c, and TLS still ends up in the exact same vendored mbedTLS
// as tls_shim.c uses, just reached through curl's own vtls/mbedtls.c
// backend instead of tls_shim.c's narrower wrapper.
//
// Same certificate-verification stance as tls_shim.c, and for the same
// reason (see its file header): CURLOPT_SSL_VERIFYPEER/VERIFYHOST are
// both off below. TLS still buys confidentiality on the wire, just not
// server-identity assurance -- fine for hitting a known-good public
// URL like this, not something to lift into anything security-
// sensitive.
//
// response_buf is static, not malloc'd or grown dynamically -- same
// fixed-footprint reasoning https_crawler.c's page_buf gives (this is
// a memory-constrained microVM -- see port/lwip_port/lwipopts.h), and
// it doubles as the buffer libcurl's write callback below appends
// into, so its size is also the effective cap on how much of a
// response this demo will keep (excess is silently dropped, not an
// error -- see write_cb()).

#include <stdio.h>
#include <string.h>

#include <curl/curl.h>

#define FETCH_URL      "https://example.com/"
#define RESPONSE_BUF_SIZE (32 * 1024)

static char response_buf[RESPONSE_BUF_SIZE];
static size_t response_len;

// libcurl's CURLOPT_WRITEFUNCTION contract: return anything other than
// size*nmemb and curl treats it as a hard write error, aborting the
// transfer -- so on overflow this still reports every byte as
// "written" (silently discarding what doesn't fit in response_buf)
// rather than failing the whole fetch over a response that was simply
// bigger than this demo cares to keep.
static size_t write_cb(char *ptr, size_t size, size_t nmemb, void *userdata)
{
	(void)userdata;
	size_t n = size * nmemb;

	size_t room = sizeof(response_buf) - 1 - response_len;
	size_t copy = n < room ? n : room;
	memcpy(response_buf + response_len, ptr, copy);
	response_len += copy;

	return n;
}

int main(void)
{
	printf("BareMetal curltest -- libcurl %s\n", curl_version());
	printf("GET %s\n\n", FETCH_URL);

	curl_global_init(CURL_GLOBAL_DEFAULT);

	CURL *h = curl_easy_init();
	if (!h) {
		printf("curl_easy_init() failed\n");
		curl_global_cleanup();
		return 1;
	}

	curl_easy_setopt(h, CURLOPT_URL, FETCH_URL);
	curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, write_cb);
	curl_easy_setopt(h, CURLOPT_USERAGENT, "BareMetal-curltest/1.0");
	curl_easy_setopt(h, CURLOPT_FOLLOWLOCATION, 1L);

	// No CA store is vendored on this port (see this file's header) --
	// without these two, mbedTLS's handshake would fail every https://
	// fetch with "unable to get local issuer certificate" instead of
	// completing one whose confidentiality is still real.
	curl_easy_setopt(h, CURLOPT_SSL_VERIFYPEER, 0L);
	curl_easy_setopt(h, CURLOPT_SSL_VERIFYHOST, 0L);

	// net_shim.c's own blocking socket calls already cap at 30s each
	// (see OPENISSUES.md) -- this just makes libcurl's own bookkeeping
	// agree with that instead of using its 0 (never time out) default.
	curl_easy_setopt(h, CURLOPT_TIMEOUT, 30L);

	CURLcode res = curl_easy_perform(h);

	if (res != CURLE_OK) {
		printf("curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
	} else {
		long status = 0;
		curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, &status);

		curl_off_t total;
		curl_easy_getinfo(h, CURLINFO_SIZE_DOWNLOAD_T, &total);

		printf("status: %ld\n", status);
		printf("body: %zu byte(s) received, %zu byte(s) kept (RESPONSE_BUF_SIZE cap)\n\n",
			(size_t)total, response_len);
		fwrite(response_buf, 1, response_len, stdout);
		printf("\n");
	}

	curl_easy_cleanup(h);
	curl_global_cleanup();

	return res == CURLE_OK ? 0 : 1;
}
